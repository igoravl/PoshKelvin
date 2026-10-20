function _TestKelvinAuthCallback {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # The URL of a main-frame navigation request.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Url,

        # The base URL of the Kelvin instance.
        [Parameter(Mandatory)]
        [uri] $BaseUrl
    )

    # The Kelvin UI (NextAuth) receives the identity provider response at /core/api/auth/callback/<provider>.
    # The login page is shown both before and after authentication, so it cannot be used on its own.
    $uri = $null
    if (-not [uri]::TryCreate($Url, [UriKind]::Absolute, [ref] $uri)) {
        return $false
    }

    $sameOrigin = [uri]::Compare($uri, $BaseUrl, [UriComponents]::SchemeAndServer, [UriFormat]::SafeUnescaped,
        [StringComparison]::OrdinalIgnoreCase) -eq 0

    return ($sameOrigin -and $uri.AbsolutePath -like '/core/api/auth/callback/*')
}
