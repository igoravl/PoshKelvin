#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe '_GetToken' {

    BeforeEach {
        Set-KelvinTestConnection
        Mock Invoke-RestMethod {
            return @{
                access_token       = 'new-access-token'
                expires_in         = 300
                refresh_token      = 'new-refresh-token'
                refresh_expires_in = 1800
            }
        } -ModuleName PoshKelvin
    }

    It 'Throws when not connected' {
        & (Get-Module PoshKelvin) { $script:KelvinSession = $null }

        { & (Get-Module PoshKelvin) { _GetToken } } | Should -Throw '*Connect-KelvinAccount*'
    }

    It 'Returns the cached access token when it is outside the refresh window' {
        $token = & (Get-Module PoshKelvin) { _GetToken }

        $token | Should -Be 'test-bearer-token'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Refreshes the access token when it is within the refresh window' {
        & (Get-Module PoshKelvin) { $script:KelvinSession.AccessTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(60) }

        $token = & (Get-Module PoshKelvin) { _GetToken }

        $token | Should -Be 'new-access-token'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/token' -and
            $Body.grant_type -eq 'refresh_token' -and
            $Body.refresh_token -eq 'test-refresh-token' -and
            $Body.client_id -eq 'kelvin-client'
        }

        $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
        $session.RefreshToken | Should -Be 'new-refresh-token'
        $session.AccessTokenExpiresAt | Should -BeGreaterThan ([DateTime]::UtcNow.AddSeconds(200))
    }

    It 'Honors the refresh window stored in the session' {
        & (Get-Module PoshKelvin) {
            $script:KelvinSession.AccessTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(60)
            $script:KelvinSession.RefreshWindow = 30
        }

        & (Get-Module PoshKelvin) { _GetToken } | Should -Be 'test-bearer-token'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Re-authenticates with the cached credentials when the refresh token is about to expire' {
        & (Get-Module PoshKelvin) {
            $script:KelvinSession.AccessTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(-1)
            $script:KelvinSession.RefreshTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(60)
        }

        & (Get-Module PoshKelvin) { _GetToken } | Should -Be 'new-access-token'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Body.grant_type -eq 'password' -and
            $Body.username -eq 'test-user' -and
            $Body.password -eq 'test-password'
        }
    }

    It 'Falls back to re-authentication when the refresh request fails' {
        & (Get-Module PoshKelvin) { $script:KelvinSession.AccessTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(-1) }
        Mock Invoke-RestMethod { throw 'invalid_grant' } -ModuleName PoshKelvin -ParameterFilter {
            $Body.grant_type -eq 'refresh_token'
        }

        & (Get-Module PoshKelvin) { _GetToken } | Should -Be 'new-access-token'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Body.grant_type -eq 'password'
        }
    }

    It 'Keeps the password as a SecureString after re-authentication' {
        & (Get-Module PoshKelvin) {
            $script:KelvinSession.AccessTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(-1)
            $script:KelvinSession.RefreshToken = $null
        }

        & (Get-Module PoshKelvin) { _GetToken } | Out-Null

        & (Get-Module PoshKelvin) { $script:KelvinSession.Password } | Should -BeOfType [securestring]
    }
}
