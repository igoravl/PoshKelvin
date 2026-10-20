#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe 'Update-KelvinToken' {
    BeforeEach {
        Set-KelvinTestConnection
        Mock Invoke-RestMethod {
            @{
                access_token       = 'new-access-token'
                expires_in         = 600
                refresh_token      = 'new-refresh-token'
                refresh_expires_in = 3600
            }
        } -ModuleName PoshKelvin
    }

    It 'Is exported as a public cmdlet' {
        (Get-Module PoshKelvin).ExportedFunctions.Keys | Should -Contain 'Update-KelvinToken'
    }

    It 'Refreshes immediately even when the access token is outside the refresh window' {
        $before = [DateTime]::UtcNow
        $result = @(Update-KelvinToken)
        $after = [DateTime]::UtcNow

        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/token' -and
            $Method -eq 'Post' -and
            $Body.grant_type -eq 'refresh_token' -and
            $Body.client_id -eq 'kelvin-client' -and
            $Body.refresh_token -eq 'test-refresh-token' -and
            -not $Body.ContainsKey('password')
        }
        $result | Should -HaveCount 1
        $result[0].PSObject.Properties.Name | Should -HaveCount 3
        $result[0].PSObject.Properties.Name | Should -Contain 'Status'
        $result[0].PSObject.Properties.Name | Should -Contain 'AccessTokenExpiresAt'
        $result[0].PSObject.Properties.Name | Should -Contain 'RefreshTokenExpiresAt'
        $result[0].Status | Should -Be 'Refreshed'
        $result[0].AccessTokenExpiresAt | Should -BeOfType [DateTime]
        $result[0].AccessTokenExpiresAt.Kind | Should -Be ([DateTimeKind]::Utc)
        $result[0].RefreshTokenExpiresAt.Kind | Should -Be ([DateTimeKind]::Utc)
        $result[0].AccessTokenExpiresAt | Should -BeGreaterOrEqual ($before.AddSeconds(600))
        $result[0].AccessTokenExpiresAt | Should -BeLessOrEqual ($after.AddSeconds(600))
        $result[0].RefreshTokenExpiresAt | Should -BeGreaterOrEqual ($before.AddSeconds(3600))
        $result[0].RefreshTokenExpiresAt | Should -BeLessOrEqual ($after.AddSeconds(3600))

        $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
        $session.AccessToken | Should -Be 'new-access-token'
        $session.RefreshToken | Should -Be 'new-refresh-token'
        $session.AccessTokenExpiresAt | Should -Be $result[0].AccessTokenExpiresAt
        $session.RefreshTokenExpiresAt | Should -Be $result[0].RefreshTokenExpiresAt
    }

    It 'Re-authenticates immediately with Force and stores both new tokens' {
        $result = Update-KelvinToken -Force

        $result.Status | Should -Be 'Reauthenticated'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Body.grant_type -eq 'password' -and
            $Body.client_id -eq 'kelvin-client' -and
            $Body.username -eq 'test-user' -and
            $Body.password -eq 'test-password' -and
            -not $Body.ContainsKey('refresh_token')
        }
        $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
        $session.Password | Should -BeOfType [securestring]
        $session.AccessToken | Should -Be 'new-access-token'
        $session.RefreshToken | Should -Be 'new-refresh-token'
        $result.AccessTokenExpiresAt | Should -Be $session.AccessTokenExpiresAt
        $result.RefreshTokenExpiresAt | Should -Be $session.RefreshTokenExpiresAt
    }

    It 'Requires a connection with Force=<Force>' -TestCases @(
        @{ Force = $false }
        @{ Force = $true }
    ) {
        param ($Force)
        & (Get-Module PoshKelvin) { $script:KelvinSession = $null }

        { Update-KelvinToken -Force:$Force } | Should -Throw '*Connect-KelvinAccount*'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Requires a refresh token in normal mode' {
        & (Get-Module PoshKelvin) { $script:KelvinSession.RefreshToken = $null }

        { Update-KelvinToken } | Should -Throw '*Update-KelvinToken -Force*'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Allows Force without a refresh token' {
        & (Get-Module PoshKelvin) { $script:KelvinSession.RefreshToken = $null }

        (Update-KelvinToken -Force).Status | Should -Be 'Reauthenticated'
    }

    It 'Requires cached credentials with Force' {
        & (Get-Module PoshKelvin) { $script:KelvinSession.Password = $null }

        { Update-KelvinToken -Force } | Should -Throw '*Connect-KelvinAccount*'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Can refresh without cached credentials' {
        & (Get-Module PoshKelvin) { $script:KelvinSession.Password = $null }

        (Update-KelvinToken).Status | Should -Be 'Refreshed'
    }

    It 'Propagates failures without returning status or changing the session with Force=<Force>' -TestCases @(
        @{ Force = $false }
        @{ Force = $true }
    ) {
        param ($Force)
        Mock Invoke-RestMethod { throw 'Token request rejected' } -ModuleName PoshKelvin
        $before = & (Get-Module PoshKelvin) { $script:KelvinSession | ConvertTo-Json }
        $results = [System.Collections.Generic.List[object]]::new()

        { Update-KelvinToken -Force:$Force | ForEach-Object { $results.Add($_) } } |
            Should -Throw '*Token request rejected*'

        $results.Count | Should -Be 0
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly
        & (Get-Module PoshKelvin) { $script:KelvinSession | ConvertTo-Json } | Should -Be $before
    }

    It 'Rejects an authentication response without an access token' {
        Mock Invoke-RestMethod { @{} } -ModuleName PoshKelvin

        { Update-KelvinToken } | Should -Throw '*No token received*'
    }

    It 'Parses the Keycloak token response shape' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{
                access_token         = 'kc-access-token'
                expires_in           = 3600
                refresh_expires_in   = 7200
                refresh_token        = 'kc-refresh-token'
                token_type           = 'Bearer'
                'not-before-policy'  = 0
                session_state        = '06e3e643-1173-490f-a62e-3f52b9c445da'
                scope                = 'kelvin-scope email openid profile'
            }
        } -ModuleName PoshKelvin
        $before = [DateTime]::UtcNow

        $result = Update-KelvinToken -Force

        $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
        $session.AccessToken | Should -Be 'kc-access-token'
        $session.RefreshToken | Should -Be 'kc-refresh-token'
        $result.AccessTokenExpiresAt | Should -BeGreaterOrEqual $before.AddSeconds(3600)
        $result.AccessTokenExpiresAt | Should -BeLessOrEqual ([DateTime]::UtcNow.AddSeconds(3600))
        $result.RefreshTokenExpiresAt | Should -BeGreaterOrEqual $before.AddSeconds(7200)
        $result.RefreshTokenExpiresAt | Should -BeLessOrEqual ([DateTime]::UtcNow.AddSeconds(7200))
    }

    It 'Treats refresh_expires_in = 0 as a refresh token without expiration' {
        Mock Invoke-RestMethod {
            @{ access_token = 'a'; expires_in = 3600; refresh_token = 'offline'; refresh_expires_in = 0 }
        } -ModuleName PoshKelvin

        $result = Update-KelvinToken -Force

        $result.RefreshTokenExpiresAt | Should -Be ([DateTime]::MaxValue)
        & (Get-Module PoshKelvin) { _GetToken -Verbose 4>$null } | Should -Be 'a'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly
    }

    It 'Keeps the current refresh token when a refresh response omits it' {
        Mock Invoke-RestMethod { @{ access_token = 'a'; expires_in = 3600 } } -ModuleName PoshKelvin
        $previousExpiry = & (Get-Module PoshKelvin) { $script:KelvinSession.RefreshTokenExpiresAt }

        Update-KelvinToken | Out-Null

        $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
        $session.RefreshToken | Should -Be 'test-refresh-token'
        $session.RefreshTokenExpiresAt | Should -Be $previousExpiry
    }

    It 'Writes troubleshooting messages without exposing secrets with Force=<Force>' -TestCases @(
        @{ Force = $false; ExpectedMessage = '*Refreshing tokens immediately*' }
        @{ Force = $true; ExpectedMessage = '*Forcing immediate re-authentication*' }
    ) {
        param ($Force, $ExpectedMessage)
        $records = @(Update-KelvinToken -Force:$Force -Verbose 4>&1)
        $messages = ($records | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join "`n"
        $results = @($records | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] })

        $messages | Should -BeLike $ExpectedMessage
        $messages | Should -BeLike '*Token update completed*'
        $messages | Should -Not -Match 'test-password|test-bearer-token|test-refresh-token|new-access-token|new-refresh-token'
        $results | Should -HaveCount 1
        $results[0].PSObject.Properties.Name | Should -HaveCount 3
    }
}
