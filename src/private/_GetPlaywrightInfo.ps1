function _GetPlaywrightInfo {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # Loads the Playwright assembly into the session when all prerequisites are installed.
        [Parameter()]
        [switch] $Import
    )

    # Keep in sync with the default -Version of scripts/Install-KelvinInteractivePrerequisites.ps1.
    $version = '1.63.0'

    $root = if ($env:POSHKELVIN_PLAYWRIGHT_PATH) {
        $env:POSHKELVIN_PLAYWRIGHT_PATH
    }
    elseif ($IsWindows -or $env:OS -eq 'Windows_NT') {
        Join-Path $env:LOCALAPPDATA 'PoshKelvin/Playwright'
    }
    else {
        $dataHome = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { Join-Path $HOME '.local/share' }
        Join-Path $dataHome 'PoshKelvin/Playwright'
    }

    $arch = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    $platform = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'win32_x64' }
    elseif ($IsMacOS) { "darwin-$arch" }
    else { "linux-$arch" }

    $packagePath = Join-Path $root $version
    $assemblyPath = Join-Path $packagePath 'Microsoft.Playwright.dll'
    $nodePath = Join-Path $packagePath ".playwright/node/$platform/$(if ($platform -like 'win32*') { 'node.exe' } else { 'node' })"
    $browsersPath = Join-Path $root 'browsers'

    $missing = [Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $assemblyPath -PathType Leaf)) { $missing.Add("Playwright $version assembly") }
    if (-not (Test-Path -LiteralPath $nodePath -PathType Leaf)) { $missing.Add("Playwright driver for $platform") }
    if (-not (Test-Path -Path (Join-Path $browsersPath 'chromium-*') -PathType Container)) { $missing.Add('Chromium browser') }

    $info = [PSCustomObject]@{
        Version      = $version
        Root         = $root
        AssemblyPath = $assemblyPath
        BrowsersPath = $browsersPath
        Platform     = $platform
        Missing      = $missing.ToArray()
        IsInstalled  = $missing.Count -eq 0
    }

    Write-Verbose ("Playwright {0} at '{1}': {2}" -f $version, $root,
        $(if ($info.IsInstalled) { 'installed' } else { "missing $($missing -join ', ')" }))

    if ($Import -and $info.IsInstalled) {
        $loaded = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Microsoft.Playwright' } | Select-Object -First 1
        if ($loaded) {
            Write-Verbose "Playwright assembly already loaded from '$($loaded.Location)'."
        }
        else {
            Write-Verbose "Loading Playwright assembly from '$assemblyPath'."
            Add-Type -LiteralPath $assemblyPath -ErrorAction Stop
        }
    }

    return $info
}
