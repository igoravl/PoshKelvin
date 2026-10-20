function _ConvertFromKelvinAuthSession {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # The raw JSON returned by the Kelvin UI session endpoint (/api/auth/session).
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Json
    )

    $expiredMessage = 'The Kelvin browser session is empty or has expired. Run Connect-KelvinAccount -Interactive again.'

    $raw = $Json.Trim()
    if (-not $raw -or $raw -eq '{}') {
        throw $expiredMessage
    }

    try {
        $session = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw 'The Kelvin session endpoint did not return valid JSON.'
    }

    if ($session -isnot [PSCustomObject]) {
        throw 'The Kelvin session endpoint returned an unexpected response.'
    }

    # NextAuth nests the tokens under "token"; accept a top-level token object as well.
    $tokenData = if ($session.PSObject.Properties['token'] -and $session.token -is [PSCustomObject]) { $session.token } else { $session }

    function Get-FirstValue([object] $Source, [string[]] $Names) {
        foreach ($name in $Names) {
            if ($Source -and $Source.PSObject.Properties[$name] -and $Source.$name) {
                return $Source.$name
            }
        }
    }

    $accessToken = Get-FirstValue $tokenData @('accessToken', 'access_token')
    if (-not $accessToken -or $accessToken -isnot [string]) {
        if ($session.PSObject.Properties.Name.Count -eq 0) { throw $expiredMessage }
        throw "No access token was found in the Kelvin session. Top-level properties: $($session.PSObject.Properties.Name -join ', ')"
    }

    $refreshToken = Get-FirstValue $tokenData @('refreshToken', 'refresh_token')
    if ($refreshToken -isnot [string]) { $refreshToken = $null }

    # The NextAuth fields (token.exp, token.iat, token.expiresIn, expires) describe the browser
    # session cookie, not the Keycloak tokens. Expiration dates are taken from the JWT claims.
    $epoch = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
    $accessClaims = _GetJwtClaims -Token $accessToken
    if (-not $accessClaims -or -not $accessClaims.PSObject.Properties['exp']) {
        throw 'Unable to determine the expiration of the access token returned by the Kelvin session.'
    }
    $accessTokenExpiresAt = $epoch.AddSeconds([long] $accessClaims.exp)

    $refreshTokenExpiresAt = [DateTime]::MinValue
    if ($refreshToken) {
        $refreshClaims = _GetJwtClaims -Token $refreshToken
        $refreshTokenExpiresAt = if ($refreshClaims -and $refreshClaims.PSObject.Properties['exp'] -and [long] $refreshClaims.exp -gt 0) {
            $epoch.AddSeconds([long] $refreshClaims.exp)
        }
        else {
            # Mirrors the password flow: a refresh token without an expiration (e.g. offline token) never expires.
            Write-Verbose 'Refresh token has no expiration.'
            [DateTime]::SpecifyKind([DateTime]::MaxValue, [DateTimeKind]::Utc)
        }
    }

    $now = [DateTime]::UtcNow
    if ($accessTokenExpiresAt -le $now -and (-not $refreshToken -or $refreshTokenExpiresAt -le $now)) {
        throw $expiredMessage
    }

    $user = if ($session.PSObject.Properties['user']) { $session.user } else { $null }
    $username = Get-FirstValue $tokenData @('email', 'name')
    if (-not $username) { $username = Get-FirstValue $user @('email', 'name') }
    if (-not $username) { $username = Get-FirstValue $accessClaims @('email', 'preferred_username', 'sub') }

    $clientId = Get-FirstValue $accessClaims @('azp')
    if (-not $clientId) { $clientId = 'kelvin-core' }

    [PSCustomObject]@{
        AccessToken           = $accessToken
        AccessTokenExpiresAt  = $accessTokenExpiresAt
        RefreshToken          = $refreshToken
        RefreshTokenExpiresAt = $refreshTokenExpiresAt
        ClientId              = [string] $clientId
        Username              = [string] $username
    }
}
