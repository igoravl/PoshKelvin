<#
.SYNOPSIS
    Disconnects from the current Kelvin instance.

.DESCRIPTION
    Clears the module-scoped session created by Connect-KelvinAccount, discarding
    the cached connection details, credentials and tokens. The cached password is
    disposed. Subsequent cmdlets require a new call to Connect-KelvinAccount.

    Tokens are not revoked on the server; they remain valid until they expire.

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

    if ($session.Password -is [securestring]) {
        $session.Password.Dispose()
    }

    $script:KelvinSession = $null

    Write-Verbose "Disconnected from Kelvin service at $($session.Url)"
}
