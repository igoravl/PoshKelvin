# Shared helpers and fixtures for PoshKelvin unit tests.
# This file is dot-sourced (not imported as a module) by each test file.

$script:ModulePath  = "$PSScriptRoot/../output/PoshKelvin"
$script:KelvinUrl   = 'https://kelvin.example.com/api/v4'
$script:KelvinToken = 'test-bearer-token'

# Sets the private script-scoped connection variables inside the loaded module so
# that cmdlets that require a prior Connect-KelvinAccount call will succeed.
function Set-KelvinTestConnection {
    & (Get-Module PoshKelvin) {
        $script:KelvinURL   = 'https://kelvin.example.com/api/v4'
        $script:KelvinToken = 'test-bearer-token'
    }
}

# Creates a simple PSCustomObject with an arbitrary set of name=value pairs.
function New-KelvinObject {
    param ([hashtable] $Properties = @{})
    $obj = [PSCustomObject] @{}
    foreach ($key in $Properties.Keys) {
        $obj | Add-Member -NotePropertyName $key -NotePropertyValue $Properties[$key]
    }
    return $obj
}
