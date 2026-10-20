#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe 'Disconnect-KelvinAccount' {

    BeforeEach {
        Mock Invoke-RestMethod { } -ModuleName PoshKelvin -ParameterFilter { $Uri -like '*/logout' }
    }

    It 'Calls the logout endpoint with the refresh token' {
        Set-KelvinTestConnection

        Disconnect-KelvinAccount

        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/logout' -and
            $Method -eq 'Post' -and
            $Body.client_id -eq 'kelvin-client' -and
            $Body.refresh_token -eq 'test-refresh-token'
        }
    }

    It 'Skips the logout endpoint when there is no refresh token' {
        Set-KelvinTestConnection
        & (Get-Module PoshKelvin) { $script:KelvinSession.RefreshToken = $null }

        Disconnect-KelvinAccount

        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
        & (Get-Module PoshKelvin) { $script:KelvinSession } | Should -BeNullOrEmpty
    }

    It 'Warns and still clears the session when the logout request fails' {
        Set-KelvinTestConnection
        Mock Invoke-RestMethod { throw 'Network error' } -ModuleName PoshKelvin -ParameterFilter { $Uri -like '*/logout' }

        Disconnect-KelvinAccount -WarningVariable warnings -WarningAction SilentlyContinue

        $warnings | Should -HaveCount 1
        $warnings[0] | Should -BeLike '*server-side*'
        & (Get-Module PoshKelvin) { $script:KelvinSession } | Should -BeNullOrEmpty
    }

    It 'Clears the session' {
        Set-KelvinTestConnection

        Disconnect-KelvinAccount

        & (Get-Module PoshKelvin) { $script:KelvinSession } | Should -BeNullOrEmpty
    }

    It 'Disposes the cached password' {
        Set-KelvinTestConnection
        $password = & (Get-Module PoshKelvin) { $script:KelvinSession.Password }

        Disconnect-KelvinAccount

        { $password.Copy() } | Should -Throw '*disposed*'
    }

    It 'Does not fail when not connected' {
        & (Get-Module PoshKelvin) { $script:KelvinSession = $null }

        { Disconnect-KelvinAccount -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Makes API calls require a new connection' {
        Set-KelvinTestConnection

        Disconnect-KelvinAccount

        { Invoke-KelvinApi 'some/path' } | Should -Throw '*Connect-KelvinAccount*'
    }

    It 'Does not dispose the password of the credential passed to Connect-KelvinAccount' {
        Mock Invoke-RestMethod {
            return @{
                access_token       = 'returned-token'
                expires_in         = 300
                refresh_token      = 'returned-refresh-token'
                refresh_expires_in = 1800
            }
        } -ModuleName PoshKelvin
        $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
        Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred

        Disconnect-KelvinAccount

        $cred.GetNetworkCredential().Password | Should -Be 'pass'
    }
}
