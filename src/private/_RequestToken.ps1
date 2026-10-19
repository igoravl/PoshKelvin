function _RequestToken {
    [CmdletBinding()]
    param (
        # The session object whose token endpoint is called and whose tokens are updated.
        [Parameter(Mandatory)]
        [PSCustomObject] $Session,

        # Uses the refresh token grant instead of the password grant.
        [Parameter()]
        [switch] $UseRefreshToken
    )

    if ($UseRefreshToken) {
        $body = @{
            grant_type    = 'refresh_token'
            client_id     = $Session.ClientId
            refresh_token = $Session.RefreshToken
        }
    }
    else {
        $body = @{
            grant_type = 'password'
            client_id  = $Session.ClientId
            username   = $Session.Username
            password   = [pscredential]::new($Session.Username, $Session.Password).GetNetworkCredential().Password
        }
    }

    # Captured before the request so that network latency never extends the computed token lifetime
    $requestedAt = [DateTime]::UtcNow

    $response = Invoke-RestMethod -Uri $Session.TokenUrl -Method Post -Body $body -ErrorAction Stop

    if (-not $response -or -not $response.access_token) {
        throw 'Authentication failed. No token received.'
    }

    $Session.AccessToken = $response.access_token
    $Session.AccessTokenExpiresAt = $requestedAt.AddSeconds([int] $response.expires_in)
    $Session.RefreshToken = $response.refresh_token
    $Session.RefreshTokenExpiresAt = $requestedAt.AddSeconds([int] $response.refresh_expires_in)
}
