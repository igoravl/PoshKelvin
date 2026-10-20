function _GetToken {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [switch] $Renew
    )

    $session = $script:KelvinSession

    if (-not $session -or -not $session.AccessToken) {
        Write-Verbose 'No active Kelvin session found.'
        throw 'Not connected to Kelvin. Use Connect-KelvinAccount first.'
    }

    $now = [DateTime]::UtcNow
    $threshold = $now.AddSeconds($session.RefreshWindow)

    Write-Verbose ("Access token expires in {0}s; refresh token expires in {1}s; refresh window is {2}s" -f `
            [long]($session.AccessTokenExpiresAt - $now).TotalSeconds,
            [long]($session.RefreshTokenExpiresAt - $now).TotalSeconds,
            $session.RefreshWindow)

    if (-not $Renew -and $session.AccessTokenExpiresAt -gt $threshold) {
        Write-Verbose 'Using cached access token.'
        return $session.AccessToken
    }

    if ($session.RefreshToken -and $session.RefreshTokenExpiresAt -gt $threshold) {
        Write-Verbose 'Renewing the access token using the cached refresh token.'

        try {
            _RequestToken -Session $session -UseRefreshToken
            Write-Verbose 'Access token refreshed successfully.'
            return $session.AccessToken
        }
        catch {
            Write-Verbose "Token refresh failed: $_. Falling back to re-authentication."
        }
    }
    elseif (-not $session.RefreshToken) {
        Write-Verbose 'Access token expired or about to expire and no refresh token is available. Re-authenticating with cached credentials.'
    }
    else {
        Write-Verbose 'Refresh token expired or about to expire. Re-authenticating with cached credentials.'
    }

    if (-not $session.Username -or -not $session.Password) {
        Write-Verbose 'Cannot re-authenticate: the session has no cached credentials.'
        if ($session.AuthenticationMode -eq 'Interactive') {
            throw 'The interactive session has expired and cannot be renewed. Use Connect-KelvinAccount -Interactive again.'
        }
        throw 'Session expired and no cached credentials are available. Use Connect-KelvinAccount again.'
    }

    _RequestToken -Session $session
    Write-Verbose "Re-authenticated successfully as '$($session.Username)'."

    return $session.AccessToken
}
