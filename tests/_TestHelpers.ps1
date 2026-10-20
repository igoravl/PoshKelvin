# Shared helpers and fixtures for PoshKelvin unit tests.
# This file is dot-sourced (not imported as a module) by each test file.

$script:ModulePath = "$PSScriptRoot/../output/PoshKelvin"

# Sets the private script-scoped session object inside the loaded module so
# that cmdlets that require a prior Connect-KelvinAccount call will succeed.
function Set-KelvinTestConnection {
    & (Get-Module PoshKelvin) {
        $script:KelvinSession = [PSCustomObject]@{
            Url                   = 'https://kelvin.example.com/api/v4'
            TokenUrl              = 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/token'
            LogoutUrl             = 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/logout'
            ClientId              = 'kelvin-client'
            Username              = 'test-user'
            Password              = ConvertTo-SecureString 'test-password' -AsPlainText -Force
            AccessToken           = 'test-bearer-token'
            AccessTokenExpiresAt  = [DateTime]::UtcNow.AddHours(1)
            RefreshToken          = 'test-refresh-token'
            RefreshTokenExpiresAt = [DateTime]::UtcNow.AddHours(2)
            RefreshWindow         = 120
        }
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
