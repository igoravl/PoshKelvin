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
    # Ensure the .NET global tools directory is in PATH for this session
    $dotnetToolsPath = Join-Path ([System.Environment]::GetFolderPath('UserProfile')) '.dotnet' 'tools'
    if ($env:PATH -notlike "*$dotnetToolsPath*") {
        $env:PATH = "$dotnetToolsPath$([System.IO.Path]::PathSeparator)$env:PATH"
    }

    # Install GitVersion.Tool if not available
    if (-not (Get-Command dotnet-gitversion -ErrorAction SilentlyContinue)) {
        Write-Host 'GitVersion not found. Installing via dotnet tool...'
        dotnet tool install --global GitVersion.Tool
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

    $buildParams = @{
        Path       = (Resolve-Path 'src').Path
        Version    = $env:GitVersion_MajorMinorPatch
    }

    Write-Host "Building version $($env:GitVersion_SemVer) (ModuleVersion: $($env:GitVersion_MajorMinorPatch))"
    Build-Module @buildParams

    # Update ReleaseNotes in the compiled manifest to point to the current version
    $version = $env:GitVersion_MajorMinorPatch
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

