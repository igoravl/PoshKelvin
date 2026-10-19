#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe 'Disconnect-KelvinAccount' {

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
