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
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred -RefreshWindow 45

            $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
            $session.RefreshToken | Should -Be 'returned-refresh-token'
            $session.AccessTokenExpiresAt | Should -BeGreaterOrEqual $before.AddSeconds(300)
            $session.AccessTokenExpiresAt | Should -BeLessOrEqual ([DateTime]::UtcNow.AddSeconds(300))
            $session.RefreshTokenExpiresAt | Should -BeGreaterOrEqual $before.AddSeconds(1800)
            $session.RefreshWindow | Should -Be 45
        }

        It 'Defaults the refresh window to two minutes' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred

            & (Get-Module PoshKelvin) { $script:KelvinSession.RefreshWindow } | Should -Be 120
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

    Context 'Interactive authentication' {

        BeforeEach {
            & (Get-Module PoshKelvin) { $script:KelvinSession = $null }
            Mock _InvokeKelvinOAuthLogin {
                $Session.AccessToken = 'oauth-access-token'
                $Session.AccessTokenExpiresAt = [DateTime]::UtcNow.AddHours(1)
                $Session.RefreshToken = 'oauth-refresh-token'
                $Session.RefreshTokenExpiresAt = [DateTime]::UtcNow.AddHours(2)
                $Session.Username = 'user@example.com'
            } -ModuleName PoshKelvin
            Mock Invoke-RestMethod { throw 'No token endpoint request expected.' } -ModuleName PoshKelvin
        }

        It 'Stores an interactive session for the public kelvin-client' {
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Interactive

            $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
            $session.AccessToken | Should -Be 'oauth-access-token'
            $session.RefreshToken | Should -Be 'oauth-refresh-token'
            $session.ClientId | Should -Be 'kelvin-client'
            $session.Username | Should -Be 'user@example.com'
            $session.Password | Should -BeNullOrEmpty
            $session.AuthenticationMode | Should -Be 'Interactive'
        }

        It 'Uses the service root for sign-in and the API version for the session URL' {
            Connect-KelvinAccount -Url 'https://kelvin.example.com/api/v5' -Interactive -RefreshWindow 30

            Should -Invoke _InvokeKelvinOAuthLogin -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
                $BaseUrl -eq 'https://kelvin.example.com' -and $Timeout -eq 300
            }
            $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
            $session.Url | Should -Be 'https://kelvin.example.com/api/v5'
            $session.TokenUrl | Should -Be 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/token'
            $session.LogoutUrl | Should -Be 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/logout'
            $session.RefreshWindow | Should -Be 30
        }

        It 'Forwards a custom -Timeout and -ApiVersion' {
            Connect-KelvinAccount 'https://kelvin.example.com/' -Interactive -Timeout 42 -ApiVersion v3

            Should -Invoke _InvokeKelvinOAuthLogin -ModuleName PoshKelvin -ParameterFilter { $Timeout -eq 42 }
            & (Get-Module PoshKelvin) { $script:KelvinSession.Url } | Should -Be 'https://kelvin.example.com/api/v3'
        }

        It 'Ignores the credential environment variables' {
            $env:KELVIN_USERNAME = 'env-user'
            $env:KELVIN_PASSWORD = 'env-pass'
            try {
                Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Interactive

                $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
                $session.Username | Should -Be 'user@example.com'
                $session.Password | Should -BeNullOrEmpty
            }
            finally {
                Remove-Item Env:\KELVIN_USERNAME -ErrorAction SilentlyContinue
                Remove-Item Env:\KELVIN_PASSWORD -ErrorAction SilentlyContinue
            }
        }

        It 'Does not write to the pipeline' {
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Interactive | Should -BeNullOrEmpty
        }

        It 'Cannot be combined with -Credentials' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            { Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Interactive -Credentials $cred } |
                Should -Throw -ErrorId 'AmbiguousParameterSet,Connect-KelvinAccount'
        }

        It 'Rejects -Timeout without -Interactive' {
            $cred = [pscredential]::new('admin', (ConvertTo-SecureString 'pass' -AsPlainText -Force))
            { Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Credentials $cred -Timeout 10 } |
                Should -Throw -ErrorId 'AmbiguousParameterSet,Connect-KelvinAccount'
        }

        It 'Keeps the existing session when the sign-in fails' {
            Set-KelvinTestConnection
            Mock _InvokeKelvinOAuthLogin { throw 'Timed out after 300 seconds waiting for OAuth authentication.' } -ModuleName PoshKelvin

            { Connect-KelvinAccount -Url 'https://other.example.com/' -Interactive -ErrorAction Stop } |
                Should -Throw '*Timed out*'
            & (Get-Module PoshKelvin) { $script:KelvinSession.AccessToken } | Should -Be 'test-bearer-token'
        }
    }
}
