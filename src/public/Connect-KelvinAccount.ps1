<#
.SYNOPSIS
    Connects to a Kelvin instance.

.DESCRIPTION
    Authenticates against a Kelvin service using the provided URL and credentials.
    Upon successful authentication, stores the connection details, credentials and
    tokens in a module-scoped session object for use by subsequent cmdlets. The
    password is kept as a SecureString, and the access token is refreshed
    automatically when it is about to expire.

.EXAMPLE
    PS> $cred = Get-Credential
    PS> Connect-KelvinAccount -Url https://my-instance.kelvin.ai/ -Credentials $cred

    Connects to a Kelvin instance with the default API version (v4).

.EXAMPLE
    PS> Connect-KelvinAccount https://my-instance.kelvin.ai/ -Credentials $cred -ApiVersion v3

    Connects to a Kelvin instance targeting a specific API version.

.EXAMPLE
    PS> $env:KELVIN_USERNAME = 'admin'
    PS> $env:KELVIN_PASSWORD = 'secret'
    PS> Connect-KelvinAccount https://my-instance.kelvin.ai/

    Connects using credentials from environment variables.
#>

function Connect-KelvinAccount {
    [CmdletBinding()]
    param (
        # The base URL of the Kelvin service (e.g. https://my-instance.kelvin.ai/).
        [Parameter(Mandatory = $true, Position = 0)]
        [uri] $Url,

        # A PSCredential object containing the username and password for authentication.
        # If not supplied, the KELVIN_USERNAME and KELVIN_PASSWORD environment variables are used.
        [Parameter()]
        [pscredential] $Credentials,

        # The API version to target. Defaults to 'v4'.
        [Parameter()]
        [ValidateScript({ $_ -match 'v\d+' })]
        [string] $ApiVersion = 'v4',

        # The refresh window (in seconds) before the access token expires. If the token 
        # is set to expire within this window, it will be refreshed. Defaults to 300 seconds (5 minutes).
        [Parameter()]
        [int] $RefreshWindow = 300
    )

    $endpointUrl = $Url.AbsoluteUri.TrimEnd('/')
    Write-Verbose "Connecting to Kelvin service at $endpointUrl"

    if ($endpointUrl -match '^(.+)/api/v\d+$') {
        $baseUrl = $Matches[1]
        Write-Verbose "URL already includes an API version. Ignoring the ApiVersion parameter."
    }
    else {
        $baseUrl = $endpointUrl
        $endpointUrl = "$endpointUrl/api/$ApiVersion"
        Write-Verbose "URL updated to include API version '$ApiVersion': $endpointUrl"
    }

    # Extract username and password from the PSCredential object, if present.
    # Otherwise, use KELVIN_USERNAME and KELVIN_PASSWORD environment variables.
    if ($Credentials) {
        $Username = $Credentials.UserName
        # Copy so the session owns its SecureString and can dispose it without affecting the caller
        $Password = $Credentials.Password.Copy()
    }
    elseif ($env:KELVIN_USERNAME -and $env:KELVIN_PASSWORD) {
        $Username = $env:KELVIN_USERNAME
        $Password = ConvertTo-SecureString $env:KELVIN_PASSWORD -AsPlainText -Force
    }

    if (-not $Username -or -not $Password -or $Password.Length -eq 0) {
        Write-Error "Username and Password must be provided either via -Credentials parameter or KELVIN_USERNAME and KELVIN_PASSWORD environment variables."
        return
    }

    $session = [PSCustomObject]@{
        Url                   = $endpointUrl
        TokenUrl              = "$baseUrl/auth/realms/kelvin/protocol/openid-connect/token"
        ClientId              = 'kelvin-client'
        Username              = $Username
        Password              = $Password
        AccessToken           = $null
        AccessTokenExpiresAt  = [DateTime]::MinValue
        RefreshToken          = $null
        RefreshTokenExpiresAt = [DateTime]::MinValue
        RefreshWindow         = $RefreshWindow
    }

    Write-Verbose "Authenticating against Kelvin service at $($session.TokenUrl)"

    try {
        _RequestToken -Session $session
    }
    catch {
        Write-Error "An error occurred during authentication: $_"
        return
    }

    Write-Verbose "Successfully authenticated against Kelvin service."

    $script:KelvinSession = $session
}
