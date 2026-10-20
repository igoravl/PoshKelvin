#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force

    function Set-KelvinInteractiveTestConnection {
        Set-KelvinTestConnection
        & (Get-Module PoshKelvin) {
            $script:KelvinSession.ClientId = 'kelvin-client'
            $script:KelvinSession.Username = 'user@example.com'
            $script:KelvinSession.Password = $null
            $script:KelvinSession | Add-Member -NotePropertyName AuthenticationMode -NotePropertyValue 'Interactive' -Force
        }
    }
}

Describe 'Interactive session lifecycle' {

    BeforeEach {
        Set-KelvinInteractiveTestConnection
        Mock Invoke-RestMethod {
            return @{
                access_token       = 'new-access-token'
                expires_in         = 3600
                refresh_token      = 'new-refresh-token'
                refresh_expires_in = 7200
            }
        } -ModuleName PoshKelvin
    }

    It 'Renews an expiring access token with the refresh token and the session client ID' {
        & (Get-Module PoshKelvin) { $script:KelvinSession.AccessTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(10) }

        & (Get-Module PoshKelvin) { _GetToken } | Should -Be 'new-access-token'

        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Body.grant_type -eq 'refresh_token' -and $Body.client_id -eq 'kelvin-client' -and
            $Body.refresh_token -eq 'test-refresh-token' -and -not $Body.ContainsKey('password')
        }
        & (Get-Module PoshKelvin) { $script:KelvinSession.RefreshToken } | Should -Be 'new-refresh-token'
    }

    It 'Asks for a new interactive connection when the refresh token has expired' {
        & (Get-Module PoshKelvin) {
            $script:KelvinSession.AccessTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(-1)
            $script:KelvinSession.RefreshTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(-1)
        }

        { & (Get-Module PoshKelvin) { _GetToken } } | Should -Throw '*Connect-KelvinAccount -Interactive*'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Asks for a new interactive connection when the refresh is rejected' {
        Mock Invoke-RestMethod { throw 'invalid_grant' } -ModuleName PoshKelvin
        & (Get-Module PoshKelvin) { $script:KelvinSession.AccessTokenExpiresAt = [DateTime]::UtcNow.AddSeconds(-1) }

        { & (Get-Module PoshKelvin) { _GetToken } } | Should -Throw '*Connect-KelvinAccount -Interactive*'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly
    }

    It 'Refreshes with Update-KelvinToken' {
        (Update-KelvinToken).Status | Should -Be 'Refreshed'
    }

    It 'Explains that Update-KelvinToken -Force is not available' {
        { Update-KelvinToken -Force } | Should -Throw '*Connect-KelvinAccount -Interactive*'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Disconnects using the session client ID' {
        Disconnect-KelvinAccount

        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/openid-connect/logout' -and $Body.client_id -eq 'kelvin-client' -and $Body.refresh_token -eq 'test-refresh-token'
        }
        & (Get-Module PoshKelvin) { $script:KelvinSession } | Should -BeNullOrEmpty
    }
}

Describe 'Credential session mode' {

    It 'Marks password sessions with the Credentials authentication mode' {
        Mock Invoke-RestMethod {
            return @{ access_token = 'token'; expires_in = 300; refresh_token = 'refresh'; refresh_expires_in = 1800 }
        } -ModuleName PoshKelvin
        $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))

        Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred

        & (Get-Module PoshKelvin) { $script:KelvinSession.AuthenticationMode } | Should -Be 'Credentials'
    }
}
