#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe 'Connect-KelvinAccount' {

    Context 'Successful authentication' {

        BeforeAll {
            Mock Invoke-RestMethod {
                return @{
                    access_token       = 'returned-token'
                    expires_in         = 300
                    refresh_token      = 'returned-refresh-token'
                    refresh_expires_in = 1800
                }
            } -ModuleName PoshKelvin
        }

        It 'Stores the access token in the module scope' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred

            $token = & (Get-Module PoshKelvin) { $script:KelvinSession.AccessToken }
            $token | Should -Be 'returned-token'
        }

        It 'Appends the default API version to the URL' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred

            $url = & (Get-Module PoshKelvin) { $script:KelvinSession.Url }
            $url | Should -Be 'https://kelvin.example.com/api/v4'
        }

        It 'Respects a custom -ApiVersion' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred -ApiVersion v3

            $url = & (Get-Module PoshKelvin) { $script:KelvinSession.Url }
            $url | Should -Be 'https://kelvin.example.com/api/v3'
        }

        It 'Does not modify a URL that already contains an API version' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            Connect-KelvinAccount -Url 'https://kelvin.example.com/api/v5' -Credentials $cred

            $url = & (Get-Module PoshKelvin) { $script:KelvinSession.Url }
            $url | Should -Be 'https://kelvin.example.com/api/v5'
        }

        It 'Accepts credentials from environment variables' {
            $env:KELVIN_USERNAME = 'env-user'
            $env:KELVIN_PASSWORD = 'env-pass'
            try {
                Connect-KelvinAccount -Url 'https://kelvin.example.com/'

                $token = & (Get-Module PoshKelvin) { $script:KelvinSession.AccessToken }
                $token | Should -Be 'returned-token'
            }
            finally {
                Remove-Item Env:\KELVIN_USERNAME -ErrorAction SilentlyContinue
                Remove-Item Env:\KELVIN_PASSWORD -ErrorAction SilentlyContinue
            }
        }

        It 'Stores the password as a SecureString' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred

            $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
            $session.Username | Should -Be 'admin'
            $session.Password | Should -BeOfType [securestring]
            [pscredential]::new('x', $session.Password).GetNetworkCredential().Password | Should -Be 'pass'
        }

        It 'Stores the password from environment variables as a SecureString' {
            $env:KELVIN_USERNAME = 'env-user'
            $env:KELVIN_PASSWORD = 'env-pass'
            try {
                Connect-KelvinAccount -Url 'https://kelvin.example.com/'

                $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
                $session.Password | Should -BeOfType [securestring]
            }
            finally {
                Remove-Item Env:\KELVIN_USERNAME -ErrorAction SilentlyContinue
                Remove-Item Env:\KELVIN_PASSWORD -ErrorAction SilentlyContinue
            }
        }

        It 'Stores the refresh token, expiration times and refresh window' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            $before = [DateTime]::UtcNow
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred -RefreshWindow 120

            $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
            $session.RefreshToken | Should -Be 'returned-refresh-token'
            $session.AccessTokenExpiresAt | Should -BeGreaterOrEqual $before.AddSeconds(300)
            $session.AccessTokenExpiresAt | Should -BeLessOrEqual ([DateTime]::UtcNow.AddSeconds(300))
            $session.RefreshTokenExpiresAt | Should -BeGreaterOrEqual $before.AddSeconds(1800)
            $session.RefreshWindow | Should -Be 120
        }

        It 'Uses the service root for the token endpoint when the URL contains an API version' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            Connect-KelvinAccount -Url 'https://kelvin.example.com/api/v5' -Credentials $cred

            Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -ParameterFilter {
                $Uri -eq 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/token'
            }
        }

        It 'Calls the correct OpenID Connect token endpoint' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred

            Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -ParameterFilter {
                $Uri -eq 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/token' -and
                $Method -eq 'Post'
            }
        }

        It 'Sends the correct credential fields in the request body' {
            $cred = [pscredential]::new('testuser', (ConvertTo-SecureString 'testpass' -AsPlainText -Force))
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred

            Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -ParameterFilter {
                $Body.username -eq 'testuser' -and
                $Body.password -eq 'testpass' -and
                $Body.client_id -eq 'kelvin-client' -and
                $Body.grant_type -eq 'password'
            }
        }
    }

    Context 'Missing credentials' {

        BeforeAll {
            Remove-Item Env:\KELVIN_USERNAME -ErrorAction SilentlyContinue
            Remove-Item Env:\KELVIN_PASSWORD -ErrorAction SilentlyContinue
        }

        It 'Writes an error when no credentials and no environment variables are set' {
            { Connect-KelvinAccount -Url 'https://kelvin.example.com/' -ErrorAction Stop } |
                Should -Throw
        }
    }

    Context 'Authentication failure' {

        BeforeEach {
            & (Get-Module PoshKelvin) { $script:KelvinSession = $null }
        }

        It 'Does not create a session when authentication fails' {
            Mock Invoke-RestMethod { throw 'Network error' } -ModuleName PoshKelvin
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' `
                -Credentials ([pscredential]::new('admin', (ConvertTo-SecureString 'p' -AsPlainText -Force))) `
                -ErrorAction SilentlyContinue

            & (Get-Module PoshKelvin) { $script:KelvinSession } | Should -BeNullOrEmpty
        }

        It 'Writes an error when the response contains no access_token' {
            Mock Invoke-RestMethod { return @{} } -ModuleName PoshKelvin
            { Connect-KelvinAccount -Url 'https://kelvin.example.com/' `
                -Credentials ([pscredential]::new('admin', (ConvertTo-SecureString 'p' -AsPlainText -Force))) `
                -ErrorAction Stop } |
                Should -Throw
        }

        It 'Writes an error when Invoke-RestMethod throws' {
            Mock Invoke-RestMethod { throw 'Network error' } -ModuleName PoshKelvin
            { Connect-KelvinAccount -Url 'https://kelvin.example.com/' `
                -Credentials ([pscredential]::new('admin', (ConvertTo-SecureString 'p' -AsPlainText -Force))) `
                -ErrorAction Stop } |
                Should -Throw
        }
    }
}
