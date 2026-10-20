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

# Builds an unsigned JWT with the given payload claims. Only the payload is meaningful to the module.
function New-KelvinTestJwt {
    param ([hashtable] $Claims = @{})
    $encode = {
        param ([string] $Text)
        [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }
    '{0}.{1}.signature' -f (& $encode '{"alg":"none","typ":"JWT"}'), (& $encode ($Claims | ConvertTo-Json -Compress))
}

# Returns the Unix time (seconds) for a point relative to now.
function Get-KelvinTestUnixTime {
    param ([int] $OffsetSeconds = 0)
    [DateTimeOffset]::UtcNow.AddSeconds($OffsetSeconds).ToUnixTimeSeconds()
}

# Builds a Kelvin UI (NextAuth) session JSON document with JWT tokens.
function New-KelvinTestSessionJson {
    param (
        [int] $AccessLifetime = 3600,
        [int] $RefreshLifetime = 7200,
        [string] $ClientId = 'kelvin-core',
        [switch] $NoRefreshToken
    )
    $token = [ordered]@{
        name        = 'Test User'
        email       = 'user@example.com'
        accessToken = New-KelvinTestJwt @{ exp = Get-KelvinTestUnixTime $AccessLifetime; azp = $ClientId; typ = 'Bearer' }
        idToken     = New-KelvinTestJwt @{ exp = Get-KelvinTestUnixTime $AccessLifetime; typ = 'ID' }
        expiresIn   = 1790722234
        iat         = Get-KelvinTestUnixTime
        exp         = Get-KelvinTestUnixTime 600
    }
    if (-not $NoRefreshToken) {
        $token.refreshToken = New-KelvinTestJwt @{ exp = Get-KelvinTestUnixTime $RefreshLifetime; azp = $ClientId; typ = 'Refresh' }
    }
    [ordered]@{
        user    = @{ name = 'Test User'; email = 'user@example.com' }
        expires = [DateTime]::UtcNow.AddMinutes(10).ToString('o')
        token   = $token
    } | ConvertTo-Json -Depth 5
}
