# DO NOT CALL THIS FILE DIRECTLY
# ==============================
# This file is used by the build system to manage the build process.
# It is not intended to be executed directly by users.
#
# Instead, use the build.ps1 script to run the build process.

task Build {
    # Compile the module in the src folder
    Import-Module ModuleBuilder

    $buildParams = @{
        Path = (Resolve-Path 'src').Path
    }

    if ($env:GitVersion_MajorMinorPatch) {
        $buildParams['Version'] = $env:GitVersion_MajorMinorPatch
        Write-Host "Building version $($env:GitVersion_SemVer) (ModuleVersion: $($env:GitVersion_MajorMinorPatch))"
    }

    Build-Module @buildParams
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

task Package Test, {
    # Generate the nupkg for publication
    # Import-Module ModuleBuilder
    # Build-Module -Path 'src'
}

task Publish Package, {
    # Publish the module to a NuGet feed
    $modulePath = Get-ChildItem -Path 'output' -Filter '*.psd1' -Recurse | Select-Object -First 1

    if ($null -eq $modulePath) {
        throw "No module manifest found in output directory."
    }

    if ([string]::IsNullOrEmpty($FeedUrl) -or [string]::IsNullOrEmpty($ApiKey)) {
        throw "FeedUrl and ApiKey must be provided."
    }

    Publish-Module -Path $modulePath.FullName -Repository $FeedUrl -NuGetApiKey $ApiKey
}

task . Build, Test, Package

