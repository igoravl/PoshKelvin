<#
.SYNOPSIS
    Connects to a Kelvin instance.

.DESCRIPTION
    Authenticates against a Kelvin service using the provided URL and credentials.
    Upon successful authentication, stores the connection details and access token
    in module-scoped variables for use by subsequent cmdlets.

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
        [string] $ApiVersion = 'v4'
    )

    $endpointUrl = $Url.AbsoluteUri.TrimEnd('/')
    Write-Verbose "Connecting to Kelvin service at $endpointUrl"

    # Define the authentication endpoint
    $authEndpoint = "$endpointUrl/auth/realms/kelvin/protocol/openid-connect/token"
    Write-Verbose "Authenticating against Kelvin service at $authEndpoint"

    # Extract username and password from the PSCredential object, if present.
    # Otherwise, use KELVIN_USERNAME and KELVIN_PASSWORD environment variables.
    # If neither are available, fails
    if ($Credentials) {
        $Username = $Credentials.UserName
        $Password = $Credentials.GetNetworkCredential().Password
    }
    else {
        $Username = $env:KELVIN_USERNAME
        $Password = $env:KELVIN_PASSWORD
    }

    if (-not $Username -or -not $Password) {
        Write-Error "Username and Password must be provided either via -Credentials parameter or KELVIN_USERNAME and KELVIN_PASSWORD environment variables."
        return
    }

    # Prepare the body for the authentication request
    $body = @{
        username   = $Username
        password   = $Password
        client_id  = "kelvin-client"
        grant_type = "password"
    }

    try {
        # Make the authentication request
        $response = Invoke-RestMethod -Uri $authEndpoint -Method Post -Body $body

        # Check if the response contains a token
        if ($response -and $response.access_token) {
            Write-Verbose "Successfully authenticated against Kelvin service."

            if ($endpointUrl -notmatch '/api/v\d+$') {
                $endpointUrl = "$endpointUrl/api/$ApiVersion"
                Write-Verbose "URL updated to include API version '$ApiVersion': $endpointUrl"
            }
            else {
                Write-Verbose "URL already includes API version '$ApiVersion'. Ignoring the ApiVersion parameter."
            }

            # Store the URL, credentials, and token in script-scoped variables
            $script:KelvinURL = $endpointUrl
            $script:KelvinUsername = $Username
            $script:KelvinPassword = $Password
            $script:KelvinToken = $response.access_token
        }
        else {
            Write-Error "Authentication failed. No token received."
        }
    }
    catch {
        Write-Error "An error occurred during authentication: $_"
    }
}
