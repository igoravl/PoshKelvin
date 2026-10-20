function _InvokeKelvinBrowserLogin {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # The base URL of the Kelvin instance (without the /api/<version> suffix).
        [Parameter(Mandatory)]
        [uri] $BaseUrl,

        # The maximum time, in seconds, to wait for the user to complete authentication.
        [Parameter(Mandatory)]
        [int] $Timeout,

        # Runs the browser without a window. Intended for automated tests only.
        [Parameter()]
        [switch] $Headless
    )

    $info = _GetPlaywrightInfo -Import
    if (-not $info.IsInstalled) {
        throw "Interactive authentication prerequisites are missing: $($info.Missing -join ', ')."
    }

    $base = $BaseUrl.AbsoluteUri.TrimEnd('/')
    $sessionPaths = @('/api/auth/session', '/core/api/auth/session')
    $eventPrefix = "PoshKelvin.InteractiveLogin.$([guid]::NewGuid().ToString('N'))"
    $previousBrowsersPath = $env:PLAYWRIGHT_BROWSERS_PATH

    $playwright = $null
    $browser = $null
    $context = $null

    try {
        $env:PLAYWRIGHT_BROWSERS_PATH = $info.BrowsersPath

        Write-Verbose "Launching Chromium (headless: $([bool] $Headless))."
        $playwright = [Microsoft.Playwright.Playwright]::CreateAsync().GetAwaiter().GetResult()
        $launchOptions = [Microsoft.Playwright.BrowserTypeLaunchOptions]::new()
        $launchOptions.Headless = [bool] $Headless
        # The prerequisites script installs only the full Chromium build (no headless shell).
        $launchOptions.Channel = 'chromium'
        $browser = $playwright.Chromium.LaunchAsync($launchOptions).GetAwaiter().GetResult()

        # A fresh, non-persistent context: no cookies or storage are kept after the browser closes.
        $context = $browser.NewContextAsync().GetAwaiter().GetResult()
        $page = $context.NewPageAsync().GetAwaiter().GetResult()

        $null = Register-ObjectEvent -InputObject $page -EventName Request -SourceIdentifier "$eventPrefix.Request"
        $null = Register-ObjectEvent -InputObject $page -EventName Close -SourceIdentifier "$eventPrefix.Close"
        $null = Register-ObjectEvent -InputObject $browser -EventName Disconnected -SourceIdentifier "$eventPrefix.Disconnected"

        Write-Host "Complete the sign-in in the browser window. Waiting up to $Timeout seconds..."
        Write-Verbose "Opening $base/"

        $gotoOptions = [Microsoft.Playwright.PageGotoOptions]::new()
        $gotoOptions.WaitUntil = [Microsoft.Playwright.WaitUntilState]::Commit
        $gotoOptions.Timeout = [float] ($Timeout * 1000)
        $null = $page.GotoAsync("$base/", $gotoOptions)

        $deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
        $callbackSeen = $false
        $authenticated = $false

        while (-not $authenticated) {
            foreach ($evt in @(Get-Event | Where-Object { $_.SourceIdentifier -like "$eventPrefix.*" })) {
                Remove-Event -EventIdentifier $evt.EventIdentifier

                switch ($evt.SourceIdentifier) {
                    "$eventPrefix.Request" {
                        # Playwright events use EventHandler<IRequest>, so the request is the second argument.
                        $request = $evt.SourceArgs[1]
                        if (-not $callbackSeen -and $request.IsNavigationRequest -and $request.Frame -eq $page.MainFrame -and
                            (_TestKelvinAuthCallback -Url $request.Url -BaseUrl $base)) {
                            Write-Verbose 'Identity provider callback detected. Waiting for the browser to return to Kelvin.'
                            $callbackSeen = $true
                        }
                    }
                    default {
                        throw 'The browser was closed before authentication completed.'
                    }
                }
            }

            if ($callbackSeen) {
                $current = $null
                if ([uri]::TryCreate($page.Url, [UriKind]::Absolute, [ref] $current) -and
                    $current.GetLeftPart([UriPartial]::Authority) -eq ([uri] $base).GetLeftPart([UriPartial]::Authority) -and
                    $current.AbsolutePath -notlike '/core/api/auth/*' -and $current.AbsolutePath -notlike '/auth/*') {
                    Write-Verbose 'The browser returned to Kelvin after authentication.'
                    $authenticated = $true
                    break
                }
            }

            if ([DateTime]::UtcNow -ge $deadline) {
                throw "Timed out after $Timeout seconds waiting for interactive authentication to complete."
            }

            Start-Sleep -Milliseconds 200
        }

        $sessionGotoOptions = [Microsoft.Playwright.PageGotoOptions]::new()
        $sessionGotoOptions.Timeout = 30000

        foreach ($path in $sessionPaths) {
            Write-Verbose "Reading the session from $base$path"
            try {
                $response = $page.GotoAsync("$base$path", $sessionGotoOptions).GetAwaiter().GetResult()
            }
            catch {
                Write-Verbose "Failed to open $path`: $($_.Exception.Message)"
                continue
            }

            $contentType = if ($response) { $response.Headers['content-type'] }
            if (-not $response -or -not $response.Ok -or $contentType -notlike '*json*') {
                Write-Verbose ("{0} did not return JSON (status {1}, content type '{2}')." -f $path, $response.Status, $contentType)
                continue
            }

            return $response.TextAsync().GetAwaiter().GetResult()
        }

        throw "Unable to read the session from the Kelvin UI ($($sessionPaths -join ', '))."
    }
    finally {
        Get-EventSubscriber | Where-Object { $_.SourceIdentifier -like "$eventPrefix.*" } | Unregister-Event -Force
        Get-Event | Where-Object { $_.SourceIdentifier -like "$eventPrefix.*" } | Remove-Event

        foreach ($disposable in @($context, $browser)) {
            if ($disposable) {
                try { $null = $disposable.CloseAsync().GetAwaiter().GetResult() }
                catch { Write-Verbose "Error closing the browser: $($_.Exception.Message)" }
            }
        }

        if ($playwright) { $playwright.Dispose() }
        $env:PLAYWRIGHT_BROWSERS_PATH = $previousBrowsersPath
        Write-Verbose 'Browser closed.'
    }
}
