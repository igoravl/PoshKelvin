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

    $grantType = if ($UseRefreshToken) { 'refresh_token' } else { 'password' }
    Write-Verbose "Requesting token from $($Session.TokenUrl) (grant type: '$grantType', client: '$($Session.ClientId)', user: '$($Session.Username)')"

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

    Write-Verbose "Token request completed in $([int]([DateTime]::UtcNow - $requestedAt).TotalMilliseconds) ms"

    if (-not $response -or -not $response.access_token) {
        Write-Verbose 'Token response did not contain an access token.'
        throw 'Authentication failed. No token received.'
    }

    if (-not $response.refresh_token) {
        Write-Verbose 'Token response did not contain a refresh token. Re-authentication will be required when the access token expires.'
    }

    $Session.AccessToken = $response.access_token
    $Session.AccessTokenExpiresAt = $requestedAt.AddSeconds([int] $response.expires_in)
    $Session.RefreshToken = $response.refresh_token
    $Session.RefreshTokenExpiresAt = $requestedAt.AddSeconds([int] $response.refresh_expires_in)

    Write-Verbose ("Token received. Access token expires in {0}s (at {1:o}); refresh token expires in {2}s (at {3:o})" -f `
            $response.expires_in, $Session.AccessTokenExpiresAt, $response.refresh_expires_in, $Session.RefreshTokenExpiresAt)
}
