<#
.SYNOPSIS
    Renews the current Kelvin session tokens immediately.

.DESCRIPTION
    Uses the cached refresh token to request new tokens immediately, regardless
    of the access token's remaining lifetime or the configured refresh window.
    Use -Force to re-authenticate with the cached credentials instead, requesting
    both a new access token and a new refresh token.

    This command is intended for troubleshooting renewal or renewing tokens early.
    It is not necessary for normal use: API commands automatically renew tokens
    when needed after Connect-KelvinAccount.

    A failed refresh raises an error rather than falling back to password
    authentication. Use -Force if the refresh token is unavailable or rejected.
    Sessions created with Connect-KelvinAccount -Interactive have no cached
    credentials, so -Force is not available for them; connect again instead.
    No status object is returned when the operation fails.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Status (Refreshed or Reauthenticated), AccessTokenExpiresAt and
    RefreshTokenExpiresAt. Expiration dates are UTC. Tokens and credentials
    are not included.

.EXAMPLE
    PS> Update-KelvinToken -Verbose

    Refreshes tokens immediately and returns the operation status and expiration dates.

.EXAMPLE
    PS> Update-KelvinToken -Force -Verbose

    Re-authenticates with the cached credentials to obtain both tokens.
#>

function Update-KelvinToken {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # Re-authenticate with the cached credentials instead of using the refresh token.
        [Parameter()]
        [switch] $Force
    )

    $session = $script:KelvinSession

    if (-not $session -or -not $session.AccessToken) {
        Write-Verbose 'No active Kelvin session found.'
        throw 'Not connected to Kelvin. Use Connect-KelvinAccount first.'
    }

    if ($Force) {
        if (-not $session.Username -or -not $session.Password) {
            Write-Verbose 'Cannot re-authenticate: the session has no cached credentials.'
            if ($session.AuthenticationMode -eq 'Interactive') {
                throw 'Interactive sessions have no cached credentials. Use Update-KelvinToken without -Force, or Connect-KelvinAccount -Interactive again.'
            }
            throw 'No cached credentials are available. Use Connect-KelvinAccount again.'
        }

        Write-Verbose 'Forcing immediate re-authentication to renew both tokens.'
        _RequestToken -Session $session
        $status = 'Reauthenticated'
    }
    else {
        if (-not $session.RefreshToken) {
            Write-Verbose 'Cannot refresh: the session has no refresh token.'
            throw 'No refresh token is available. Use Update-KelvinToken -Force or Connect-KelvinAccount again.'
        }

        Write-Verbose 'Refreshing tokens immediately, regardless of the configured refresh window.'
        _RequestToken -Session $session -UseRefreshToken
        $status = 'Refreshed'
    }

    Write-Verbose ("Token update completed ({0}). Access token expires at {1:o}; refresh token expires at {2:o}" -f `
            $status, $session.AccessTokenExpiresAt, $session.RefreshTokenExpiresAt)

    [PSCustomObject]@{
        Status                = $status
        AccessTokenExpiresAt  = $session.AccessTokenExpiresAt
        RefreshTokenExpiresAt = $session.RefreshTokenExpiresAt
    }
}
