#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe '_GetJwtClaims' {

    It 'Decodes the payload of a JWT' {
        $jwt = New-KelvinTestJwt @{ exp = 1234; azp = 'kelvin-core' }
        $claims = InModuleScope PoshKelvin -Parameters @{ Jwt = $jwt } { param ($Jwt) _GetJwtClaims -Token $Jwt }

        $claims.exp | Should -Be 1234
        $claims.azp | Should -Be 'kelvin-core'
    }

    It 'Returns nothing for values that are not JWTs' -TestCases @(
        @{ Token = '' }
        @{ Token = 'opaque-token' }
        @{ Token = 'a.!!!.c' }
    ) {
        param ($Token)
        InModuleScope PoshKelvin -Parameters @{ Token = $Token } { param ($Token) _GetJwtClaims -Token $Token } |
            Should -BeNullOrEmpty
    }
}

Describe '_ConvertFromKelvinAuthSession' {

    BeforeAll {
        function Invoke-Convert([string] $Json) {
            InModuleScope PoshKelvin -Parameters @{ Json = $Json } { param ($Json) _ConvertFromKelvinAuthSession -Json $Json }
        }
    }

    It 'Extracts the tokens from a NextAuth session' {
        $json = New-KelvinTestSessionJson
        $expected = $json | ConvertFrom-Json

        $result = Invoke-Convert $json

        $result.AccessToken | Should -Be $expected.token.accessToken
        $result.RefreshToken | Should -Be $expected.token.refreshToken
        $result.ClientId | Should -Be 'kelvin-core'
        $result.Username | Should -Be 'user@example.com'
    }

    It 'Takes expiration dates from the JWT claims, not from the NextAuth session fields' {
        $result = Invoke-Convert (New-KelvinTestSessionJson -AccessLifetime 3600 -RefreshLifetime 7200)

        $result.AccessTokenExpiresAt | Should -BeGreaterThan ([DateTime]::UtcNow.AddSeconds(3590))
        $result.AccessTokenExpiresAt | Should -BeLessOrEqual ([DateTime]::UtcNow.AddSeconds(3601))
        $result.RefreshTokenExpiresAt | Should -BeGreaterThan ([DateTime]::UtcNow.AddSeconds(7190))
        $result.AccessTokenExpiresAt.Kind | Should -Be 'Utc'
    }

    It 'Uses the azp claim as the client ID' {
        (Invoke-Convert (New-KelvinTestSessionJson -ClientId 'other-client')).ClientId | Should -Be 'other-client'
    }

    It 'Accepts top-level snake_case tokens' {
        $access = New-KelvinTestJwt @{ exp = Get-KelvinTestUnixTime 600; preferred_username = 'jdoe' }
        $json = @{ access_token = $access; refresh_token = 'opaque' } | ConvertTo-Json

        $result = Invoke-Convert $json

        $result.AccessToken | Should -Be $access
        $result.RefreshToken | Should -Be 'opaque'
        $result.ClientId | Should -Be 'kelvin-core'
        $result.Username | Should -Be 'jdoe'
        $result.RefreshTokenExpiresAt | Should -Be ([DateTime]::MaxValue)
    }

    It 'Leaves the refresh token empty when the session has none' {
        $result = Invoke-Convert (New-KelvinTestSessionJson -NoRefreshToken)

        $result.RefreshToken | Should -BeNullOrEmpty
        $result.RefreshTokenExpiresAt | Should -Be ([DateTime]::MinValue)
    }

    It 'Accepts an expired access token when the refresh token is still valid' {
        $result = Invoke-Convert (New-KelvinTestSessionJson -AccessLifetime -10)
        $result.AccessTokenExpiresAt | Should -BeLessThan ([DateTime]::UtcNow)
    }

    It 'Rejects <Case>' -TestCases @(
        @{ Case = 'an empty response'; Json = ''; Message = '*empty or has expired*' }
        @{ Case = 'an empty session'; Json = '{}'; Message = '*empty or has expired*' }
        @{ Case = 'invalid JSON'; Json = '<html></html>'; Message = '*valid JSON*' }
        @{ Case = 'a non-object response'; Json = '[1,2]'; Message = '*unexpected response*' }
        @{ Case = 'a session without an access token'; Json = '{"user":{"name":"x"},"token":{}}'; Message = '*No access token*' }
        @{ Case = 'an access token without expiration'; Json = '{"token":{"accessToken":"opaque"}}'; Message = '*expiration*' }
    ) {
        param ($Json, $Message)
        { Invoke-Convert $Json } | Should -Throw $Message
    }

    It 'Rejects a session whose tokens have all expired' {
        { Invoke-Convert (New-KelvinTestSessionJson -AccessLifetime -10 -RefreshLifetime -5) } |
            Should -Throw '*empty or has expired*'
        { Invoke-Convert (New-KelvinTestSessionJson -AccessLifetime -10 -NoRefreshToken) } |
            Should -Throw '*empty or has expired*'
    }

    It 'Does not include token values in error messages' {
        $access = New-KelvinTestJwt @{ azp = 'kelvin-core' }
        $json = @{ token = @{ accessToken = $access } } | ConvertTo-Json

        try { Invoke-Convert $json } catch { $message = $_.Exception.Message }

        $message | Should -Not -BeNullOrEmpty
        $message | Should -Not -BeLike "*$access*"
    }
}

Describe '_TestKelvinAuthCallback' {

    It 'Returns <Expected> for <Url>' -TestCases @(
        @{ Url = 'https://kelvin.example.com/core/api/auth/callback/keycloak?code=x&state=y'; Expected = $true }
        @{ Url = 'https://KELVIN.example.com/core/api/auth/callback/keycloak'; Expected = $true }
        @{ Url = 'https://kelvin.example.com/core/login?callbackUrl=%2Fassets'; Expected = $false }
        @{ Url = 'https://kelvin.example.com/core/login?callbackUrl=/core/api/auth/callback/keycloak'; Expected = $false }
        @{ Url = 'https://kelvin.example.com/auth/realms/kelvin/broker/microsoft/endpoint?code=x'; Expected = $false }
        @{ Url = 'https://evil.example.net/core/api/auth/callback/keycloak'; Expected = $false }
        @{ Url = 'http://kelvin.example.com/core/api/auth/callback/keycloak'; Expected = $false }
        @{ Url = 'not a url'; Expected = $false }
    ) {
        param ($Url, $Expected)
        InModuleScope PoshKelvin -Parameters @{ Url = $Url } {
            param ($Url) _TestKelvinAuthCallback -Url $Url -BaseUrl 'https://kelvin.example.com'
        } | Should -Be $Expected
    }
}
