#Requires -Module Pester

BeforeDiscovery {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    # Real-browser tests are opt-in: they need Playwright Chromium and are unstable when run
    # in the same process as the rest of the suite.
    $script:PlaywrightReady = $env:POSHKELVIN_BROWSER_TESTS -eq '1' -and
        $PSVersionTable.PSVersion.Major -ge 7 -and
        (& (Get-Module PoshKelvin) { (_GetPlaywrightInfo).IsInstalled })
}

Describe '_InvokeKelvinBrowserLogin' -Skip:(-not $script:PlaywrightReady) -Tag 'Integration' {
    BeforeAll {
        . "$PSScriptRoot/_TestHelpers.ps1"
        Import-Module $script:ModulePath -Force

        $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $probe.Start()
        $port = $probe.LocalEndpoint.Port
        $probe.Stop()

        $script:BaseUrl = "http://127.0.0.1:$port"
        $script:ModeFile = Join-Path $TestDrive 'mode.txt'
        $script:SessionFile = Join-Path $TestDrive 'session.json'
        $script:StopFile = Join-Path $TestDrive 'stop'
        Set-Content -Path $script:ModeFile -Value 'auto'
        Set-Content -Path $script:SessionFile -Value (New-KelvinTestSessionJson)

        $script:Server = Start-Job -ArgumentList $port, $script:ModeFile, $script:SessionFile, $script:StopFile -ScriptBlock {
            param ($Port, $ModeFile, $SessionFile, $StopFile)

            $listener = [System.Net.HttpListener]::new()
            $listener.Prefixes.Add("http://127.0.0.1:$Port/")
            $listener.Start()

            function Send-Response($Context, [int] $Status, [string] $Body = '', [string] $ContentType = 'text/html', [hashtable] $Headers = @{}) {
                $response = $Context.Response
                $response.StatusCode = $Status
                $response.ContentType = $ContentType
                foreach ($key in $Headers.Keys) { $response.Headers[$key] = $Headers[$key] }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.Close()
            }

            try {
                while (-not (Test-Path $StopFile)) {
                    $pending = $listener.GetContextAsync()
                    while (-not $pending.Wait(200)) {
                        if (Test-Path $StopFile) { return }
                    }

                    $context = $pending.Result
                    $mode = (Get-Content -Path $ModeFile -Raw).Trim()
                    $path = $context.Request.Url.AbsolutePath
                    $authenticated = $context.Request.Headers['Cookie'] -like '*auth=1*'

                    switch -Wildcard ($path) {
                        '/' {
                            Send-Response $context 302 -Headers @{ Location = '/core/login?callbackUrl=/assets' }
                        }
                        '/core/login' {
                            $script = if (-not $authenticated -and $mode -ne 'manual') {
                                "<script>setTimeout(function () { location.href = '/auth/realms/kelvin/protocol/openid-connect/auth?client_id=kelvin-core'; }, 100);</script>"
                            }
                            Send-Response $context 200 "<html><body>Login $script</body></html>"
                        }
                        '/auth/realms/kelvin/protocol/openid-connect/auth' {
                            Send-Response $context 302 -Headers @{ Location = '/core/api/auth/callback/keycloak?code=abc&state=xyz' }
                        }
                        '/core/api/auth/callback/keycloak' {
                            Send-Response $context 302 -Headers @{
                                Location     = '/core/login?callbackUrl=%2Fassets'
                                'Set-Cookie' = 'auth=1; Path=/'
                            }
                        }
                        '/api/auth/session' {
                            if ($mode -eq 'fallback' -or -not $authenticated) {
                                Send-Response $context 404 'Not found' 'text/plain'
                            }
                            else {
                                Send-Response $context 200 (Get-Content -Path $SessionFile -Raw) 'application/json'
                            }
                        }
                        '/core/api/auth/session' {
                            $body = if ($authenticated) { Get-Content -Path $SessionFile -Raw } else { '{}' }
                            Send-Response $context 200 $body 'application/json'
                        }
                        default {
                            Send-Response $context 404 'Not found' 'text/plain'
                        }
                    }
                }
            }
            finally {
                $listener.Stop()
            }
        }

        $deadline = [DateTime]::UtcNow.AddSeconds(15)
        while ([DateTime]::UtcNow -lt $deadline) {
            try {
                $client = [System.Net.Sockets.TcpClient]::new('127.0.0.1', $port)
                $client.Dispose()
                break
            }
            catch {
                Start-Sleep -Milliseconds 100
            }
        }
    }

    AfterAll {
        Set-Content -Path $script:StopFile -Value 'stop'
        $script:Server | Wait-Job -Timeout 10 | Out-Null
        $script:Server | Remove-Job -Force
    }

    It 'Returns the session JSON after the identity provider callback' {
        Set-Content -Path $script:ModeFile -Value 'auto'

        $json = & (Get-Module PoshKelvin) { param ($Url) _InvokeKelvinBrowserLogin -BaseUrl $Url -Timeout 60 -Headless } $script:BaseUrl

        @($json).Count | Should -Be 1
        $json | Should -BeOfType [string]
        ($json | ConvertFrom-Json).token.email | Should -Be 'user@example.com'
    }

    It 'Falls back to the /core session endpoint' {
        Set-Content -Path $script:ModeFile -Value 'fallback'

        $json = & (Get-Module PoshKelvin) { param ($Url) _InvokeKelvinBrowserLogin -BaseUrl $Url -Timeout 60 -Headless } $script:BaseUrl

        ($json | ConvertFrom-Json).token.accessToken | Should -Not -BeNullOrEmpty
    }

    It 'Times out when authentication is not completed and cleans up its event subscriptions' {
        Set-Content -Path $script:ModeFile -Value 'manual'

        { & (Get-Module PoshKelvin) { param ($Url) _InvokeKelvinBrowserLogin -BaseUrl $Url -Timeout 3 -Headless } $script:BaseUrl } |
            Should -Throw '*Timed out after 3 seconds*'

        Get-EventSubscriber | Where-Object SourceIdentifier -like 'PoshKelvin.InteractiveLogin.*' | Should -BeNullOrEmpty
        Get-Event | Where-Object SourceIdentifier -like 'PoshKelvin.InteractiveLogin.*' | Should -BeNullOrEmpty
    }

    It 'Produces a session accepted by the session parser' {
        Set-Content -Path $script:ModeFile -Value 'auto'

        $session = & (Get-Module PoshKelvin) {
            param ($Url)
            _ConvertFromKelvinAuthSession -Json (_InvokeKelvinBrowserLogin -BaseUrl $Url -Timeout 60 -Headless)
        } $script:BaseUrl

        $session.ClientId | Should -Be 'kelvin-core'
        $session.Username | Should -Be 'user@example.com'
    }
}
