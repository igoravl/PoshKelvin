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

        BeforeAll {
            $script:installedInfo = [PSCustomObject]@{
                Version = '1.0.0'; Root = '/pw'; IsInstalled = $true; Missing = @()
            }
        }

        BeforeEach {
            & (Get-Module PoshKelvin) { $script:KelvinSession = $null }
            $script:sessionJson = New-KelvinTestSessionJson
            Mock _GetPlaywrightInfo { $script:installedInfo } -ModuleName PoshKelvin
            Mock _InvokeKelvinBrowserLogin { $script:sessionJson } -ModuleName PoshKelvin
            Mock _ConfirmPrerequisiteInstall { $false } -ModuleName PoshKelvin
            Mock Invoke-RestMethod { throw 'No token endpoint request expected.' } -ModuleName PoshKelvin
        }

        It 'Stores the tokens read from the browser session' {
            Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Interactive

            $expected = $script:sessionJson | ConvertFrom-Json
            $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
            $session.AccessToken | Should -Be $expected.token.accessToken
            $session.RefreshToken | Should -Be $expected.token.refreshToken
            $session.ClientId | Should -Be 'kelvin-core'
            $session.Username | Should -Be 'user@example.com'
            $session.Password | Should -BeNullOrEmpty
            $session.AuthenticationMode | Should -Be 'Interactive'
            $session.AccessTokenExpiresAt | Should -BeGreaterThan ([DateTime]::UtcNow.AddMinutes(59))
            Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
        }

        It 'Uses the service root for the browser and the API version for the session URL' {
            Connect-KelvinAccount -Url 'https://kelvin.example.com/api/v5' -Interactive -RefreshWindow 30

            Should -Invoke _InvokeKelvinBrowserLogin -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
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

            Should -Invoke _InvokeKelvinBrowserLogin -ModuleName PoshKelvin -ParameterFilter { $Timeout -eq 42 }
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

        It 'Keeps the existing session when the browser sign-in fails' {
            Set-KelvinTestConnection
            Mock _InvokeKelvinBrowserLogin { throw 'Timed out after 300 seconds waiting for interactive authentication to complete.' } -ModuleName PoshKelvin

            { Connect-KelvinAccount -Url 'https://other.example.com/' -Interactive -ErrorAction Stop } |
                Should -Throw '*Timed out*'
            & (Get-Module PoshKelvin) { $script:KelvinSession.AccessToken } | Should -Be 'test-bearer-token'
        }

        It 'Does not create a session when the browser session is empty' {
            $script:sessionJson = '{}'

            { Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Interactive -ErrorAction Stop } |
                Should -Throw '*empty or has expired*'
            & (Get-Module PoshKelvin) { $script:KelvinSession } | Should -BeNullOrEmpty
        }

        Context 'Missing prerequisites' {

            BeforeEach {
                $script:missingInfo = [PSCustomObject]@{
                    Version = '1.0.0'; Root = '/pw'; IsInstalled = $false; Missing = @('Chromium browser')
                }
                Mock _GetPlaywrightInfo { $script:missingInfo } -ModuleName PoshKelvin
            }

            It 'Refers to the documentation and the setup script when the user declines' {
                { Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Interactive -ErrorAction Stop } |
                    Should -Throw '*Chromium browser*docs/interactive-authentication.md*Install-KelvinInteractivePrerequisites.ps1*'

                Should -Invoke _ConfirmPrerequisiteInstall -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter { $Path -eq '/pw' }
                Should -Invoke _InvokeKelvinBrowserLogin -ModuleName PoshKelvin -Times 0 -Exactly
                & (Get-Module PoshKelvin) { $script:KelvinSession } | Should -BeNullOrEmpty
            }

            It 'Runs the setup script when the user accepts and continues when it succeeds' {
                $script:setupMarker = Join-Path $TestDrive 'setup-ran'
                $env:POSHKELVIN_TEST_SETUP_MARKER = $script:setupMarker
                Mock _ConfirmPrerequisiteInstall { $true } -ModuleName PoshKelvin
                Mock _GetPlaywrightInfo {
                    if (Test-Path $env:POSHKELVIN_TEST_SETUP_MARKER) { $script:installedInfo } else { $script:missingInfo }
                } -ModuleName PoshKelvin

                $moduleBase = (Get-Module PoshKelvin).ModuleBase
                $scriptPath = Join-Path $moduleBase 'scripts/Install-KelvinInteractivePrerequisites.ps1'
                $backup = Get-Content -Raw $scriptPath
                try {
                    Set-Content -Path $scriptPath -Value 'New-Item -ItemType File -Path $env:POSHKELVIN_TEST_SETUP_MARKER | Out-Null'
                    Connect-KelvinAccount -Url 'https://kelvin.example.com/' -Interactive
                }
                finally {
                    Set-Content -Path $scriptPath -Value $backup -NoNewline
                    Remove-Item Env:\POSHKELVIN_TEST_SETUP_MARKER -ErrorAction SilentlyContinue
                }

                Test-Path $script:setupMarker | Should -BeTrue
                Should -Invoke _InvokeKelvinBrowserLogin -ModuleName PoshKelvin -Times 1 -Exactly
                & (Get-Module PoshKelvin) { $script:KelvinSession.AuthenticationMode } | Should -Be 'Interactive'
            }
        }
    }
}
