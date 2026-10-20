#Requires -Version 7.0

<#
.SYNOPSIS
    Installs the prerequisites for Connect-KelvinAccount -Interactive.

.DESCRIPTION
    Downloads the Microsoft.Playwright NuGet package from nuget.org, extracts the
    Playwright assembly and the driver for the current platform into a per-user
    folder, and installs the Chromium browser used for interactive authentication.

    Nothing is installed system-wide. The default location is:
      - Windows:      %LOCALAPPDATA%\PoshKelvin\Playwright
      - Linux/macOS:  $XDG_DATA_HOME/PoshKelvin/Playwright (or ~/.local/share/...)
    Set the POSHKELVIN_PLAYWRIGHT_PATH environment variable (or use -Path) to use
    another location; PoshKelvin reads the same variable when connecting.

    The Playwright package download is about 210 MB and Chromium about 170 MB.
    About 550 MB of disk space is used after installation (about 135 MB of
    package files plus about 400 MB for the browser).

.EXAMPLE
    PS> & (Join-Path (Get-Module PoshKelvin -ListAvailable | Select-Object -First 1).ModuleBase 'scripts/Install-KelvinInteractivePrerequisites.ps1')

    Installs Playwright and Chromium into the default per-user folder.

.EXAMPLE
    PS> ./Install-KelvinInteractivePrerequisites.ps1 -WithDependencies

    On Linux, also installs the operating system libraries required by Chromium
    (uses sudo and the system package manager).
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    # The Microsoft.Playwright package version to install.
    [Parameter()]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $Version = '1.63.0',

    # The installation root. Defaults to POSHKELVIN_PLAYWRIGHT_PATH or the per-user data folder.
    [Parameter()]
    [string] $Path,

    # Reinstall the package files even if they are already present.
    [Parameter()]
    [switch] $Force,

    # Linux only: also install the system libraries required by Chromium (requires sudo).
    [Parameter()]
    [switch] $WithDependencies
)

$ErrorActionPreference = 'Stop'

if (-not $Path) {
    $Path = if ($env:POSHKELVIN_PLAYWRIGHT_PATH) {
        $env:POSHKELVIN_PLAYWRIGHT_PATH
    }
    elseif ($IsWindows) {
        Join-Path $env:LOCALAPPDATA 'PoshKelvin/Playwright'
    }
    else {
        $dataHome = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { Join-Path $HOME '.local/share' }
        Join-Path $dataHome 'PoshKelvin/Playwright'
    }
}

$arch = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
$platform = if ($IsWindows) {
    if ($arch -ne 'x64') { Write-Warning "Playwright ships an x64 driver for Windows; running it on $arch relies on emulation." }
    'win32_x64'
}
elseif ($IsMacOS) { "darwin-$arch" }
else { "linux-$arch" }

$nodeName = if ($IsWindows) { 'node.exe' } else { 'node' }
$packagePath = Join-Path $Path $Version
$browsersPath = Join-Path $Path 'browsers'
$nodePath = Join-Path $packagePath ".playwright/node/$platform/$nodeName"
$cliPath = Join-Path $packagePath '.playwright/package/cli.js'
$assemblyPath = Join-Path $packagePath 'Microsoft.Playwright.dll'

if ($Force -or -not (Test-Path $assemblyPath) -or -not (Test-Path $nodePath) -or -not (Test-Path $cliPath)) {
    if ($PSCmdlet.ShouldProcess($packagePath, "Install Microsoft.Playwright $Version ($platform)")) {
        $packageUrl = "https://api.nuget.org/v3-flatcontainer/microsoft.playwright/$Version/microsoft.playwright.$Version.nupkg"
        $tempFile = Join-Path ([IO.Path]::GetTempPath()) "microsoft.playwright.$Version.$([guid]::NewGuid().ToString('N')).nupkg"
        $stagingPath = "$packagePath.staging"

        try {
            Write-Host "Downloading Microsoft.Playwright $Version from nuget.org..."
            $progress = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try { Invoke-WebRequest -Uri $packageUrl -OutFile $tempFile -UseBasicParsing }
            finally { $ProgressPreference = $progress }

            Write-Host "Extracting Playwright for $platform..."
            if (Test-Path $stagingPath) { Remove-Item $stagingPath -Recurse -Force }
            $null = New-Item -ItemType Directory -Path $stagingPath -Force

            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [IO.Compression.ZipFile]::OpenRead($tempFile)
            try {
                $prefixes = @('.playwright/package/', ".playwright/node/$platform/")
                $stagingFull = [IO.Path]::GetFullPath($stagingPath) + [IO.Path]::DirectorySeparatorChar
                $extracted = 0

                foreach ($entry in $zip.Entries) {
                    $name = [uri]::UnescapeDataString($entry.FullName)
                    $target = if ($name -eq 'lib/netstandard2.0/Microsoft.Playwright.dll') { 'Microsoft.Playwright.dll' }
                    elseif (-not $name.EndsWith('/') -and ($prefixes | Where-Object { $name.StartsWith($_) })) { $name }

                    if (-not $target) { continue }

                    $destination = [IO.Path]::GetFullPath((Join-Path $stagingPath $target))
                    if (-not $destination.StartsWith($stagingFull)) { throw "Unsafe path in package: $name" }

                    $null = New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
                    $extracted++
                }
            }
            finally {
                $zip.Dispose()
            }

            $stagedNode = Join-Path $stagingPath ".playwright/node/$platform/$nodeName"
            if (-not (Test-Path $stagedNode)) {
                throw "The Playwright package $Version does not contain a driver for platform '$platform'."
            }

            if (-not $IsWindows) {
                [IO.File]::SetUnixFileMode($stagedNode, [IO.UnixFileMode] 493) # 0755
            }

            if (Test-Path $packagePath) { Remove-Item $packagePath -Recurse -Force }
            Move-Item $stagingPath $packagePath
            Write-Host "Extracted $extracted files to $packagePath"
        }
        finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            Remove-Item $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
else {
    Write-Host "Microsoft.Playwright $Version is already installed at $packagePath"
}

$installArgs = @($cliPath, 'install', 'chromium', '--no-shell')
if ($WithDependencies) {
    if ($IsLinux) { $installArgs += '--with-deps' }
    else { Write-Warning '-WithDependencies only applies to Linux and was ignored.' }
}

if ($PSCmdlet.ShouldProcess($browsersPath, 'Install Chromium')) {
    Write-Host 'Installing Chromium (this may take a few minutes)...'
    $previous = $env:PLAYWRIGHT_BROWSERS_PATH
    $env:PLAYWRIGHT_BROWSERS_PATH = $browsersPath
    try {
        & $nodePath @installArgs
        if ($LASTEXITCODE -ne 0) { throw "Chromium installation failed with exit code $LASTEXITCODE." }
    }
    finally {
        $env:PLAYWRIGHT_BROWSERS_PATH = $previous
    }

    Write-Host 'Interactive authentication prerequisites are installed. You can now run Connect-KelvinAccount -Interactive.'
}
