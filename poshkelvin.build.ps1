# DO NOT CALL THIS FILE DIRECTLY
# ==============================
# This file is used by the build system to manage the build process.
# It is not intended to be executed directly by users.
#
# Instead, use the build.ps1 script to run the build process.

task Clean {
    # Remove the output directory
    if (Test-Path 'output') {
        Remove-Item 'output' -Recurse -Force
        Write-Host 'Output directory cleaned.'
    }
    else {
        Write-Host 'Output directory does not exist.'
    }
}

task GenerateVersion {
    # Ensure the dotnet CLI is available before proceeding
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw "The .NET SDK (dotnet CLI) is required to run GitVersion. Please install .NET and ensure 'dotnet' is available on PATH."
    }

    # Ensure a workspace-local .NET tools directory is in PATH for this session
    $dotnetToolsPath = Join-Path $PSScriptRoot '.dotnet-tools'
    if (-not (Test-Path $dotnetToolsPath)) {
        New-Item -ItemType Directory -Path $dotnetToolsPath | Out-Null
    }
    if ($env:PATH -notlike "*$dotnetToolsPath*") {
        $env:PATH = "$dotnetToolsPath$([System.IO.Path]::PathSeparator)$env:PATH"
    }

    # Install GitVersion.Tool locally if not available
    if (-not (Get-Command dotnet-gitversion -ErrorAction SilentlyContinue)) {
        Write-Host 'GitVersion not found. Installing locally via dotnet tool...'
        dotnet tool install GitVersion.Tool --tool-path $dotnetToolsPath
    }

    Write-Host 'Running GitVersion...'
    $json = dotnet-gitversion /output json
    if ($LASTEXITCODE -ne 0) {
        throw "GitVersion failed with exit code $LASTEXITCODE."
    }

    # Expose all GitVersion variables as environment variables (GitVersion_* prefix)
    ($json | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
        Set-Item -Path "env:GitVersion_$($_.Name)" -Value $_.Value
    }

    Write-Host "Version: $($env:GitVersion_SemVer) (ModuleVersion: $($env:GitVersion_MajorMinorPatch))"
}

task Build GenerateVersion, {
    # Compile the module in the src folder
    Import-Module ModuleBuilder

    # Determine the module version to build:
    # Prefer GitVersion_MajorMinorPatch, fall back to the manifest's ModuleVersion if necessary.
    $moduleVersion = $env:GitVersion_MajorMinorPatch
    if ([string]::IsNullOrWhiteSpace($moduleVersion)) {
        Write-Warning 'GitVersion_MajorMinorPatch is not set or empty. Falling back to ModuleVersion from the module manifest.'
        $manifest = Get-ChildItem -Path 'src' -Filter 'PoshKelvin.psd1' | Select-Object -First 1
        if (-not $manifest) {
            throw "GitVersion_MajorMinorPatch is not set and no module manifest was found under 'src' to determine a version."
        }
        $manifestInfo = Test-ModuleManifest -Path $manifest.FullName
        $moduleVersion = $manifestInfo.Version.ToString()
    }

    $buildParams = @{
        Path    = (Resolve-Path 'src').Path
        Version = $moduleVersion
    }

    Write-Host "Building version $($env:GitVersion_SemVer) (ModuleVersion: $moduleVersion)"
    Build-Module @buildParams

    # Update ReleaseNotes in the compiled manifest to point to the current version
    $version = $moduleVersion
    $heading = Get-Content 'CHANGELOG.md' |
        Where-Object { $_ -match "^## \[$([regex]::Escape($version))\]" } |
        Select-Object -First 1
    $releaseNotes = if ($heading) {
        # GitHub anchor slugification: strip '## ', lowercase, keep only [a-z0-9 -], spaces -> hyphens
        $slug = ($heading -replace '^## ', '').ToLower() -replace '[^a-z0-9\s-]', '' -replace '\s+', '-'
        "https://github.com/igoravl/PoshKelvin/blob/main/CHANGELOG.md#$slug"
    } else {
        "https://github.com/igoravl/PoshKelvin/blob/main/CHANGELOG.md"
    }

    $compiledManifest = Get-ChildItem -Path 'output' -Filter '*.psd1' -Recurse | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
    if ($compiledManifest) {
        Update-ModuleManifest -Path $compiledManifest.FullName -ReleaseNotes $releaseNotes
        Write-Host "ReleaseNotes set to: $releaseNotes"
    }
    else {
        throw "No compiled module manifest found in output directory. Cannot set ReleaseNotes."
    }
}

task Test Build, {
    # Run tests using Pester (add tests under a 'tests' directory)
    if (Test-Path 'tests') {
        Import-Module Pester -MinimumVersion 5.0
        Invoke-Pester -Path 'tests' -CI
    }
    else {
        Write-Warning 'No tests directory found. Skipping tests.'
    }
}

task Verify Test, {
    # Smoke-test the compiled module: import it and list exported commands
    $compiledManifest = Get-ChildItem -Path 'output' -Filter '*.psd1' -Recurse |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $compiledManifest) {
        throw "No compiled module manifest found in output directory. Cannot verify module."
    }
    Import-Module $compiledManifest.FullName -Force
    Get-Command -Module PoshKelvin | Format-Table -AutoSize
}

task Package Verify, {
    # Fail fast when the changelog has no entry for the version being packaged
    $version = $env:GitVersion_MajorMinorPatch
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "GitVersion_MajorMinorPatch environment variable is not set or is empty. Run the GenerateVersion task before Package or ensure versioning is configured."
    }
    $heading = Get-Content 'CHANGELOG.md' |
        Where-Object { $_ -match "^## \[$([regex]::Escape($version))\]" } |
        Select-Object -First 1
    if (-not $heading) {
        throw "CHANGELOG.md does not contain an entry for version $version. Add a '## [$version]' section before packaging."
    }

    # Generate the nupkg for publication
    # Import-Module ModuleBuilder
    # Build-Module -Path 'src'
}

task Publish Package, {
    # Publish the module to a NuGet feed
    $modulePath = Get-ChildItem -Path 'output' -Filter '*.psd1' -Recurse | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1

    if ($null -eq $modulePath) {
        throw "No module manifest found in output directory."
    }

    if ([string]::IsNullOrEmpty($FeedUrl) -or [string]::IsNullOrEmpty($ApiKey)) {
        throw "FeedUrl and ApiKey must be provided."
    }

    Publish-Module -Path $modulePath.FullName -Repository $FeedUrl -NuGetApiKey $ApiKey
}

task . Build, Test, Package

