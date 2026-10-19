function _GetToken {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $session = $script:KelvinSession

    if (-not $session -or -not $session.AccessToken) {
        throw 'Not connected to Kelvin. Use Connect-KelvinAccount first.'
    }

    $threshold = [DateTime]::UtcNow.AddSeconds($session.RefreshWindow)

    if ($session.AccessTokenExpiresAt -gt $threshold) {
        return $session.AccessToken
    }

    if ($session.RefreshToken -and $session.RefreshTokenExpiresAt -gt $threshold) {
        Write-Verbose 'Access token expired or about to expire. Refreshing token.'

        try {
            _RequestToken -Session $session -UseRefreshToken
            return $session.AccessToken
        }
        catch {
            Write-Verbose "Token refresh failed: $_. Falling back to re-authentication."
        }
    }
    else {
        Write-Verbose 'Refresh token expired or about to expire. Re-authenticating with cached credentials.'
    }

    if (-not $session.Username -or -not $session.Password) {
        throw 'Session expired and no cached credentials are available. Use Connect-KelvinAccount again.'
    }

    _RequestToken -Session $session

    return $session.AccessToken
}
