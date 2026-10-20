#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe 'Native OAuth authentication' {
    BeforeEach {
        $script:originalRedirect = [Environment]::GetEnvironmentVariable('KELVIN_AUTH_REDIRECT_URI')
        $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $probe.Start()
        $port = $probe.LocalEndpoint.Port
        $probe.Stop()
        $env:KELVIN_AUTH_REDIRECT_URI = "http://localhost:$port/callback"
        $script:mode = 'success'
        $script:callbackJob = $null
        $script:authorizeUrl = $null
        $script:codeBody = $null
        $script:accessToken = New-KelvinTestJwt @{ preferred_username = 'user@example.com' }
        & (Get-Module PoshKelvin) { $script:KelvinSession = $null }

        Mock Invoke-RestMethod {
            if ($Body.grant_type -eq 'authorization_code') { $script:codeBody = $Body.Clone() }
            @{
                access_token       = $script:accessToken
                expires_in         = 3600
                refresh_token      = 'synthetic-refresh'
                refresh_expires_in = 7200
            }
        } -ModuleName PoshKelvin
        Mock Start-Process {
            $script:authorizeUrl = [uri] $FilePath
            $script:callbackJob = Start-Job -ArgumentList $FilePath, $script:mode -ScriptBlock {
                param ($AuthorizeUrl, $Mode)
                $redirect = [uri]::UnescapeDataString([regex]::Match($AuthorizeUrl, '[?&]redirect_uri=([^&]+)').Groups[1].Value)
                $state = [regex]::Match($AuthorizeUrl, '[?&]state=([^&]+)').Groups[1].Value
                $query = switch ($Mode) {
                    'wrong-state' { 'code=synthetic-code&state=wrong' }
                    'missing-state' { 'code=synthetic-code' }
                    'duplicate-state' { "code=synthetic-code&state=$state&state=$state" }
                    'denied' { "error=access_denied&state=$state" }
                    'missing-code' { "state=$state" }
                    'duplicate-code' { "code=one&code=two&state=$state" }
                    default { "code=synthetic-code&state=$state" }
                }
                if ($Mode -eq 'noise') {
                    try { Invoke-WebRequest ($redirect -replace '/callback$', '/favicon.ico') -UseBasicParsing -ErrorAction Stop | Out-Null }
                    catch {
                        if ([int] $_.Exception.Response.StatusCode -ne 404) { throw }
                    }
                }
                try { Invoke-WebRequest "${redirect}?$query" -UseBasicParsing -ErrorAction Stop | Out-Null }
                catch {
                    if ([int] $_.Exception.Response.StatusCode -ne 400) { throw }
                }
            }
        } -ModuleName PoshKelvin
    }

    AfterEach {
        if ($script:callbackJob) {
            $script:callbackJob | Wait-Job -Timeout 10 | Out-Null
            $script:callbackJob | Receive-Job -ErrorAction Stop | Out-Null
            $script:callbackJob | Remove-Job -Force
        }
        [Environment]::SetEnvironmentVariable('KELVIN_AUTH_REDIRECT_URI', $script:originalRedirect)
    }

    It 'Exchanges a code with PKCE using the default browser and reuses the session lifecycle' {
        $before = [DateTime]::UtcNow
        Connect-KelvinAccount 'https://kelvin.example.com/api/v5' -Interactive -Timeout 30 -RefreshWindow 45 |
            Should -BeNullOrEmpty
        $session = & (Get-Module PoshKelvin) { $script:KelvinSession }
        $session.AccessToken | Should -Be $script:accessToken
        $session.Username | Should -Be 'user@example.com'
        $session.Password | Should -BeNullOrEmpty
        $session.ClientId | Should -Be 'kelvin-client'
        $session.AuthenticationMode | Should -Be 'Interactive'
        $session.RefreshWindow | Should -Be 45
        $session.Url | Should -Be 'https://kelvin.example.com/api/v5'
        $session.AccessTokenExpiresAt | Should -BeGreaterOrEqual $before.AddSeconds(3600)
        $session.RefreshTokenExpiresAt | Should -BeLessOrEqual ([DateTime]::UtcNow.AddSeconds(7200))
        $script:authorizeUrl.AbsolutePath | Should -Be '/auth/realms/kelvin/protocol/openid-connect/auth'
        $script:authorizeUrl.Query | Should -Match 'code_challenge_method=S256'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Body.grant_type -eq 'authorization_code' -and $Body.code -eq 'synthetic-code' -and
            $Body.client_id -eq 'kelvin-client' -and $Body.redirect_uri -eq $env:KELVIN_AUTH_REDIRECT_URI -and
            $Body.code_verifier -match '^[A-Za-z0-9_-]{43}$' -and
            $Uri -eq 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/token' -and
            $ContentType -eq 'application/x-www-form-urlencoded' -and $Method -eq 'Post'
        }
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $hash = $sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($script:codeBody.code_verifier))
            $challenge = [Convert]::ToBase64String($hash).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        }
        finally { $sha.Dispose() }
        $script:authorizeUrl.Query | Should -Match "code_challenge=$challenge(&|$)"
        $script:authorizeUrl.Query | Should -Match 'state=[A-Za-z0-9_-]{43}(&|$)'
        $script:codeBody.ContainsKey('client_secret') | Should -BeFalse
        Update-KelvinToken | Select-Object -ExpandProperty Status | Should -Be 'Refreshed'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -ParameterFilter {
            $Body.grant_type -eq 'refresh_token' -and $Body.client_id -eq 'kelvin-client'
        }
        { Update-KelvinToken -Force } | Should -Throw '*Connect-KelvinAccount -Interactive*'
        Disconnect-KelvinAccount
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -ParameterFilter {
            $Uri -like '*/logout' -and $Body.client_id -eq 'kelvin-client'
        }
    }

    It 'Uses the documented default localhost port when no override is set' {
        Remove-Item Env:\KELVIN_AUTH_REDIRECT_URI
        Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -Timeout 30
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -ParameterFilter {
            $Body.redirect_uri -ceq 'http://localhost:38638/'
        }
    }

    It 'Ignores unrelated callback paths' {
        $script:mode = 'noise'
        Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -Timeout 30
        & (Get-Module PoshKelvin) { $script:KelvinSession.AccessToken } | Should -Be $script:accessToken
    }

    It 'Accepts an IPv4 loopback override and ignores credential environment variables' {
        $env:KELVIN_AUTH_REDIRECT_URI = $env:KELVIN_AUTH_REDIRECT_URI.Replace('localhost', '127.0.0.1')
        $oldUser = $env:KELVIN_USERNAME
        $oldPassword = $env:KELVIN_PASSWORD
        $env:KELVIN_USERNAME = 'ignored-user'
        $env:KELVIN_PASSWORD = 'ignored-password'
        try {
            Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -Timeout 30
            $script:codeBody.ContainsKey('password') | Should -BeFalse
            & (Get-Module PoshKelvin) { $script:KelvinSession.Username } | Should -Be 'user@example.com'
        }
        finally {
            $env:KELVIN_USERNAME = $oldUser
            $env:KELVIN_PASSWORD = $oldPassword
        }
    }

    It 'Rejects callback <Mode> without exchanging a code and preserves the existing connection' -TestCases @(
        @{ Mode = 'wrong-state' }, @{ Mode = 'missing-state' }, @{ Mode = 'duplicate-state' },
        @{ Mode = 'denied' }, @{ Mode = 'missing-code' }, @{ Mode = 'duplicate-code' }
    ) {
        param ($Mode)
        $script:mode = $Mode
        Set-KelvinTestConnection
        { Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -Timeout 30 -ErrorAction Stop } |
            Should -Throw '*OAuth*'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
        & (Get-Module PoshKelvin) { $script:KelvinSession.AccessToken } | Should -Be 'test-bearer-token'
    }

    It 'Rejects invalid redirect override <Value> before opening the browser' -TestCases @(
        @{ Value = 'https://localhost:38638/' }, @{ Value = 'http://example.com:38638/' },
        @{ Value = 'http://0.0.0.0:38638/' }, @{ Value = 'http://localhost:38638/?x=1' },
        @{ Value = 'http://user@localhost:38638/' }, @{ Value = 'http://localhost:38638/#fragment' },
        @{ Value = 'not-a-uri' }, @{ Value = 'http://localhost:0/' },
        @{ Value = 'http://[::1]:38638/' }
    ) {
        param ($Value)
        $env:KELVIN_AUTH_REDIRECT_URI = $Value
        { Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -ErrorAction Stop } |
            Should -Throw '*KELVIN_AUTH_REDIRECT_URI*'
        Should -Invoke Start-Process -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Rejects insecure authorization endpoints' {
        { Connect-KelvinAccount 'http://kelvin.example.com' -Interactive -ErrorAction Stop } |
            Should -Throw '*HTTPS*'
        Should -Invoke Start-Process -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Times out and releases the callback port' {
        Mock Start-Process {} -ModuleName PoshKelvin
        { Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -Timeout 1 -ErrorAction Stop } |
            Should -Throw '*Timed out after 1 seconds*'
        $listener = [Net.HttpListener]::new()
        $listener.Prefixes.Add(([uri] $env:KELVIN_AUTH_REDIRECT_URI).GetLeftPart([UriPartial]::Authority) + '/')
        try { { $listener.Start() } | Should -Not -Throw } finally { $listener.Close() }
    }

    It 'Fails explicitly when the callback port is already occupied' {
        $listener = [Net.HttpListener]::new()
        $listener.Prefixes.Add(([uri] $env:KELVIN_AUTH_REDIRECT_URI).GetLeftPart([UriPartial]::Authority) + '/')
        $listener.Start()
        try {
            { Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -ErrorAction Stop } |
                Should -Throw '*Cannot start the OAuth callback listener*'
        }
        finally { $listener.Close() }
        Should -Invoke Start-Process -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Prints the sign-in URL when the default browser cannot be opened' {
        Mock Start-Process { throw 'No default browser' } -ModuleName PoshKelvin
        Mock Write-Host { if ($Object -like 'https://*') { $script:printedUrl = $Object } } -ModuleName PoshKelvin
        $script:printedUrl = $null
        { Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -Timeout 1 -ErrorAction Stop -WarningVariable warnings -WarningAction SilentlyContinue } |
            Should -Throw '*Timed out after 1 seconds*'
        $script:printedUrl | Should -BeLike 'https://kelvin.example.com/auth/realms/kelvin/protocol/openid-connect/auth?client_id=kelvin-client&*'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Reports token exchange errors without echoing the code or server response' {
        Mock Invoke-RestMethod { throw 'sensitive-server-body' } -ModuleName PoshKelvin
        { Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -Timeout 30 -ErrorAction Stop } |
            Should -Throw '*OAuth authorization-code exchange failed*'
        & (Get-Module PoshKelvin) { $script:KelvinSession } | Should -BeNullOrEmpty
    }

    It 'Does not connect when the token response has no access token lifetime' {
        Mock Invoke-RestMethod { @{ access_token = 'synthetic-access' } } -ModuleName PoshKelvin
        { Connect-KelvinAccount 'https://kelvin.example.com' -Interactive -Timeout 30 -ErrorAction Stop } |
            Should -Throw '*OAuth authorization-code exchange failed*'
        & (Get-Module PoshKelvin) { $script:KelvinSession } | Should -BeNullOrEmpty
    }
}

Describe 'Authorization-code token response validation' {
    BeforeEach {
        Set-KelvinTestConnection
        $script:response = @{
            access_token = 'synthetic-access'; expires_in = 3600
            refresh_token = 'synthetic-refresh'; refresh_expires_in = 7200
        }
        Mock Invoke-RestMethod { $script:response } -ModuleName PoshKelvin
    }

    It 'Rejects invalid access tokens <Token>' -TestCases @(
        @{ Token = $null }, @{ Token = '' }, @{ Token = ' ' }, @{ Token = 123 }
    ) {
        param ($Token)
        $script:response.access_token = $Token
        {
            & (Get-Module PoshKelvin) {
                _RequestToken -Session $script:KelvinSession -AuthorizationCode 'synthetic-code' -RedirectUri 'http://localhost:38638/' -CodeVerifier 'synthetic-verifier'
            }
        } | Should -Throw '*Authentication failed*'
        & (Get-Module PoshKelvin) { $script:KelvinSession.AccessToken } | Should -Be 'test-bearer-token'
    }

    It 'Does not assume a refresh token has unlimited validity when its lifetime is unknown' {
        $script:response.Remove('refresh_expires_in')
        & (Get-Module PoshKelvin) {
            _RequestToken -Session $script:KelvinSession -AuthorizationCode 'synthetic-code' -RedirectUri 'http://localhost:38638/' -CodeVerifier 'synthetic-verifier'
            $script:KelvinSession.RefreshTokenExpiresAt
        } | Should -Be ([DateTime]::MinValue)
    }

    It 'Preserves Keycloak explicit zero refresh lifetime semantics' {
        $script:response.refresh_expires_in = 0
        & (Get-Module PoshKelvin) {
            _RequestToken -Session $script:KelvinSession -AuthorizationCode 'synthetic-code' -RedirectUri 'http://localhost:38638/' -CodeVerifier 'synthetic-verifier'
            $script:KelvinSession.RefreshTokenExpiresAt
        } | Should -Be ([DateTime]::MaxValue)
    }
}
