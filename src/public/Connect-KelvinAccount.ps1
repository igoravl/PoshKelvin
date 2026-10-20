<#
.SYNOPSIS
    Connects to a Kelvin instance.

.DESCRIPTION
    Authenticates against a Kelvin service using the provided URL and credentials.
    Upon successful authentication, stores the connection details, credentials and
    tokens in a module-scoped session object for use by subsequent cmdlets. The
    password is kept as a SecureString, and the access token is refreshed
    automatically when it is about to expire.

    It is not necessary to call Update-KelvinToken during normal use: API commands
    handle token renewal automatically. Use Update-KelvinToken only to test renewal
    or renew tokens earlier than the configured refresh window.

    Use -Interactive for instances that only support single sign-on (SSO). A
    browser window opens so you can sign in; once the browser returns to Kelvin,
    the tokens are read from the Kelvin UI session and the browser is closed.
    No password is stored: when the refresh token expires, run
    Connect-KelvinAccount -Interactive again. Interactive authentication requires
    PowerShell 7+ and the prerequisites described in
    https://github.com/igoravl/PoshKelvin/blob/main/docs/interactive-authentication.md

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

.EXAMPLE
    PS> Connect-KelvinAccount https://my-instance.kelvin.ai/ -Interactive

    Opens a browser to sign in with single sign-on and connects with the resulting tokens.

.EXAMPLE
    PS> Connect-KelvinAccount https://my-instance.kelvin.ai/ -Interactive -Timeout 600

    Waits up to 10 minutes for the browser sign-in to complete.
#>

function Connect-KelvinAccount {
    [CmdletBinding(DefaultParameterSetName = 'Credentials')]
    param (
        # The base URL of the Kelvin service (e.g. https://my-instance.kelvin.ai/).
        [Parameter(Mandatory = $true, Position = 0)]
        [uri] $Url,

        # A PSCredential object containing the username and password for authentication.
        # If not supplied, the KELVIN_USERNAME and KELVIN_PASSWORD environment variables are used.
        [Parameter(ParameterSetName = 'Credentials')]
        [pscredential] $Credentials,

        # Signs in through a browser window (single sign-on) instead of using a username and password.
        # Requires PowerShell 7+ and the Playwright prerequisites.
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive')]
        [switch] $Interactive,

        # The maximum time, in seconds, to wait for the browser sign-in to complete. Defaults to 300 seconds.
        [Parameter(ParameterSetName = 'Interactive')]
        [ValidateRange(1, 86400)]
        [int] $Timeout = 300,

        # The API version to target. Defaults to 'v4'.
        [Parameter()]
        [ValidateScript({ $_ -match 'v\d+' })]
        [string] $ApiVersion = 'v4',

        # The refresh window (in seconds) before the access token expires. If the token 
        # is set to expire within this window, it will be refreshed. Defaults to 120 seconds (2 minutes).
        [Parameter()]
        [ValidateRange(0, 2147483647)]
        [int] $RefreshWindow = 120
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

    $tokenUrl = "$baseUrl/auth/realms/kelvin/protocol/openid-connect/token"
    $logoutUrl = "$baseUrl/auth/realms/kelvin/protocol/openid-connect/logout"

    if ($Interactive) {
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-Error 'Interactive authentication requires PowerShell 7 or later. Use -Credentials on Windows PowerShell.'
            return
        }

        $playwright = _GetPlaywrightInfo
        if (-not $playwright.IsInstalled) {
            $scriptPath = Join-Path $MyInvocation.MyCommand.Module.ModuleBase 'scripts/Install-KelvinInteractivePrerequisites.ps1'

            if (_ConfirmPrerequisiteInstall -Cmdlet $PSCmdlet -Path $playwright.Root) {
                try {
                    & $scriptPath
                }
                catch {
                    Write-Warning "Installing the interactive authentication prerequisites failed: $_"
                }
                $playwright = _GetPlaywrightInfo
            }

            if (-not $playwright.IsInstalled) {
                Write-Error (("Interactive authentication prerequisites are missing ({0}). " +
                        "See https://github.com/igoravl/PoshKelvin/blob/main/docs/interactive-authentication.md, " +
                        "or install them by running: & '{1}'") -f ($playwright.Missing -join ', '), $scriptPath)
                return
            }
        }

        if ($script:KelvinSession) {
            Write-Verbose "An existing session for '$($script:KelvinSession.Username)' at $($script:KelvinSession.Url) will be replaced on successful authentication."
        }

        try {
            $sessionJson = _InvokeKelvinBrowserLogin -BaseUrl $baseUrl -Timeout $Timeout
            $tokens = _ConvertFromKelvinAuthSession -Json $sessionJson
        }
        catch {
            Write-Error "Interactive authentication failed: $_"
            return
        }

        $script:KelvinSession = [PSCustomObject]@{
            Url                   = $endpointUrl
            TokenUrl              = $tokenUrl
            LogoutUrl             = $logoutUrl
            ClientId              = $tokens.ClientId
            Username              = $tokens.Username
            Password              = $null
            AccessToken           = $tokens.AccessToken
            AccessTokenExpiresAt  = $tokens.AccessTokenExpiresAt
            RefreshToken          = $tokens.RefreshToken
            RefreshTokenExpiresAt = $tokens.RefreshTokenExpiresAt
            RefreshWindow         = $RefreshWindow
            AuthenticationMode    = 'Interactive'
        }

        Write-Verbose ("Successfully authenticated '{0}' interactively (client '{1}'). Access token expires at {2:o}; refresh token expires at {3:o}" -f `
                $tokens.Username, $tokens.ClientId, $tokens.AccessTokenExpiresAt, $tokens.RefreshTokenExpiresAt)
        Write-Verbose "Session stored. API base URL: $endpointUrl"
        return
    }

    # Extract username and password from the PSCredential object, if present.
    # Otherwise, use KELVIN_USERNAME and KELVIN_PASSWORD environment variables.
    if ($Credentials) {
        Write-Verbose 'Using credentials from the -Credentials parameter.'
        $Username = $Credentials.UserName
        # Copy so the session owns its SecureString and can dispose it without affecting the caller
        $Password = $Credentials.Password.Copy()
    }
    elseif ($env:KELVIN_USERNAME -and $env:KELVIN_PASSWORD) {
        Write-Verbose 'Using credentials from the KELVIN_USERNAME and KELVIN_PASSWORD environment variables.'
        $Username = $env:KELVIN_USERNAME
        $Password = ConvertTo-SecureString $env:KELVIN_PASSWORD -AsPlainText -Force
    }

    if (-not $Username -or -not $Password -or $Password.Length -eq 0) {
        Write-Error "Username and Password must be provided either via -Credentials parameter or KELVIN_USERNAME and KELVIN_PASSWORD environment variables."
        return
    }

    $session = [PSCustomObject]@{
        Url                   = $endpointUrl
        TokenUrl              = $tokenUrl
        LogoutUrl             = $logoutUrl
        ClientId              = 'kelvin-client'
        Username              = $Username
        Password              = $Password
        AccessToken           = $null
        AccessTokenExpiresAt  = [DateTime]::MinValue
        RefreshToken          = $null
        RefreshTokenExpiresAt = [DateTime]::MinValue
        RefreshWindow         = $RefreshWindow
        AuthenticationMode    = 'Credentials'
    }

    if ($script:KelvinSession) {
        Write-Verbose "An existing session for '$($script:KelvinSession.Username)' at $($script:KelvinSession.Url) will be replaced on successful authentication."
    }

    Write-Verbose "Authenticating as '$Username' against Kelvin service at $($session.TokenUrl) (refresh window: ${RefreshWindow}s)"

    try {
        _RequestToken -Session $session
    }
    catch {
        Write-Error "An error occurred during authentication: $_"
        return
    }

    Write-Verbose "Successfully authenticated against Kelvin service."

    $script:KelvinSession = $session
    Write-Verbose "Session stored. API base URL: $($session.Url)"
}
