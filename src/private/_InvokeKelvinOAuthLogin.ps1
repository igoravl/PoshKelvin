function _InvokeKelvinOAuthLogin {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)]
        [string] $BaseUrl,

        [Parameter(Mandatory)]
        [PSCustomObject] $Session,

        [Parameter()]
        [ValidateRange(1, 86400)]
        [int] $Timeout = 300
    )

    $serviceUri = [uri] $BaseUrl
    if (-not $serviceUri.IsAbsoluteUri -or $serviceUri.Scheme -ne 'https' -or $serviceUri.UserInfo -or $serviceUri.Query -or $serviceUri.Fragment) {
        throw 'Native OAuth authentication requires an absolute HTTPS Kelvin URL without credentials, a query, or a fragment.'
    }

    $redirectText = if (Test-Path Env:\KELVIN_AUTH_REDIRECT_URI) {
        $env:KELVIN_AUTH_REDIRECT_URI
    }
    else {
        'http://localhost:38638/'
    }
    $redirect = $null
    if (-not [uri]::TryCreate($redirectText, [UriKind]::Absolute, [ref] $redirect) -or
        $redirect.Scheme -ne 'http' -or
        $redirect.Host -notin @('localhost', '127.0.0.1') -or
        $redirect.Port -lt 1 -or $redirect.UserInfo -or $redirect.Query -or $redirect.Fragment) {
        throw 'KELVIN_AUTH_REDIRECT_URI must be an absolute HTTP loopback URL (localhost or 127.0.0.1) with a valid port and no credentials, query, or fragment. Literal IPv6 redirects are not supported by this listener.'
    }

    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = New-Object byte[] 32
        $rng.GetBytes($bytes)
        $state = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        $rng.GetBytes($bytes)
        $verifier = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        $challenge = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($verifier))).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }
    finally {
        $rng.Dispose()
        $sha.Dispose()
    }

    $redirectUri = $redirect.AbsoluteUri
    $authorizeUrl = "$BaseUrl/auth/realms/kelvin/protocol/openid-connect/auth?" +
        "client_id=kelvin-client&response_type=code&scope=openid" +
        "&redirect_uri=$([uri]::EscapeDataString($redirectUri))" +
        "&state=$state&code_challenge=$challenge&code_challenge_method=S256"

    $listener = [Net.HttpListener]::new()
    $listener.Prefixes.Add($redirect.GetLeftPart([UriPartial]::Authority) + '/')
    try {
        try { $listener.Start() }
        catch {
            throw "Cannot start the OAuth callback listener on $($redirect.GetLeftPart([UriPartial]::Authority)). Check that the port is free and the current user can listen on it."
        }

        $clock = [Diagnostics.Stopwatch]::StartNew()
        Write-Host "Complete the sign-in in your default browser. Waiting up to $Timeout seconds..."
        try { Start-Process -FilePath $authorizeUrl -ErrorAction Stop | Out-Null }
        catch {
            Write-Warning 'Unable to open the default browser. Open this URL manually to sign in:'
            Write-Host $authorizeUrl
        }

        $pending = $listener.GetContextAsync()
        while ($true) {
            if ($clock.Elapsed.TotalSeconds -ge $Timeout) {
                throw "Timed out after $Timeout seconds waiting for OAuth authentication. If the browser shows an HTTP 403, contact your Kelvin administrator."
            }
            if (-not $pending.IsCompleted) {
                Start-Sleep -Milliseconds 100
                continue
            }
            $context = $pending.GetAwaiter().GetResult()
            $callback = $context.Request
            $code = $null
            $failure = $null
            $status = 200
            $message = 'Sign-in response received. You can close this tab and check PowerShell for the connection result.'
            try {
                if (-not [Net.IPAddress]::IsLoopback($callback.RemoteEndPoint.Address) -or
                    $callback.HttpMethod -ne 'GET' -or
                    $callback.Url.Authority -ne $redirect.Authority -or
                    $callback.Url.AbsolutePath -cne $redirect.AbsolutePath) {
                    $status = 404
                    $message = 'Not found.'
                }
                elseif ($callback.QueryString.GetValues('state').Count -ne 1 -or
                    $callback.QueryString['state'] -cne $state) {
                    $status = 400
                    $message = 'Sign-in rejected: invalid OAuth state. Return to PowerShell and try again.'
                    $failure = 'OAuth callback state is missing, duplicated, or does not match. No tokens were requested.'
                }
                elseif ($callback.QueryString.GetValues('error').Count -gt 0) {
                    $status = 400
                    $message = 'Sign-in was denied by the identity provider. Return to PowerShell.'
                    $failure = 'The identity provider rejected OAuth authentication. Try again or contact your Kelvin administrator.'
                }
                elseif ($callback.QueryString.GetValues('code').Count -ne 1 -or
                    [string]::IsNullOrWhiteSpace($callback.QueryString['code'])) {
                    $status = 400
                    $message = 'Sign-in failed: no authorization code was received. Return to PowerShell.'
                    $failure = 'OAuth callback did not contain exactly one nonempty authorization code.'
                }
                else {
                    $code = $callback.QueryString['code']
                }

                $context.Response.StatusCode = $status
                $context.Response.ContentType = 'text/plain; charset=utf-8'
                $context.Response.Headers['Cache-Control'] = 'no-store'
                $context.Response.Headers['Referrer-Policy'] = 'no-referrer'
                $body = [Text.Encoding]::UTF8.GetBytes($message)
                $context.Response.ContentLength64 = $body.Length
                $context.Response.OutputStream.Write($body, 0, $body.Length)
            }
            finally {
                $context.Response.Close()
            }
            if ($failure) { throw $failure }
            if ($code) { break }
            $pending = $listener.GetContextAsync()
        }
    }
    finally {
        $listener.Close()
    }

    try {
        $remainingSeconds = [Math]::Max(1, [Math]::Ceiling($Timeout - $clock.Elapsed.TotalSeconds))
        _RequestToken -Session $Session -AuthorizationCode $code -RedirectUri $redirectUri -CodeVerifier $verifier -TimeoutSeconds $remainingSeconds
    }
    catch {
        # HTTP error bodies may contain sensitive server details; do not echo them.
        throw 'OAuth authorization-code exchange failed. Check the client redirect registration and PKCE support with your Kelvin administrator.'
    }
    $claims = _GetJwtClaims -Token $Session.AccessToken
    $Session.Username = if ($claims.preferred_username) { $claims.preferred_username } elseif ($claims.email) { $claims.email } else { $claims.sub }
}
