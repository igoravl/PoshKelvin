<#
.SYNOPSIS
    Disconnects from the current Kelvin instance.

.DESCRIPTION
    Ends the server-side session by calling the Kelvin OpenID Connect logout
    endpoint, which revokes the refresh token. Then clears the module-scoped
    session created by Connect-KelvinAccount, discarding the cached connection
    details, credentials and tokens, and disposes the cached password.
    Subsequent cmdlets require a new call to Connect-KelvinAccount.

    If the logout request fails, a warning is written and the local session is
    cleared anyway.

    Access tokens already issued are self-contained and may still be accepted by
    the API until they expire.

.EXAMPLE
    PS> Disconnect-KelvinAccount

    Clears the current Kelvin session.
#>

function Disconnect-KelvinAccount {
    [CmdletBinding()]
    [OutputType([void])]
    param ()

    $session = $script:KelvinSession

    if (-not $session) {
        Write-Verbose 'Not connected to Kelvin. Nothing to disconnect.'
        return
    }

    Write-Verbose "Disconnecting '$($session.Username)' from Kelvin service at $($session.Url)"

    if ($session.RefreshToken -and $session.LogoutUrl) {
        Write-Verbose "Ending the server-side session at $($session.LogoutUrl)"

        try {
            $body = @{
                client_id     = $session.ClientId
                refresh_token = $session.RefreshToken
            }

            Invoke-RestMethod -Uri $session.LogoutUrl -Method Post -Body $body -ErrorAction Stop | Out-Null
            Write-Verbose 'Server-side session ended. The refresh token has been revoked.'
        }
        catch {
            Write-Warning "Failed to end the server-side Kelvin session: $_. The local session will be cleared anyway."
        }
    }
    else {
        Write-Verbose 'No refresh token available. Skipping server-side logout.'
    }

    if ($session.Password -is [securestring]) {
        Write-Verbose 'Disposing the cached password.'
        $session.Password.Dispose()
    }

    $script:KelvinSession = $null

    Write-Verbose "Disconnected from Kelvin service at $($session.Url)"
}
