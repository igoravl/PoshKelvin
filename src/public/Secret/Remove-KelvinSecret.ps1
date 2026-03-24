<#
.SYNOPSIS
    Removes a secret from Kelvin.

.DESCRIPTION
    Permanently deletes one or more secrets from the currently connected Kelvin
    instance. This cannot be undone once the API request has been submitted.
    By default, prompts for confirmation before each removal.

.EXAMPLE
    PS> Remove-KelvinSecret -Name my-secret

    Removes the specified secret after confirmation.

.EXAMPLE
    PS> Remove-KelvinSecret -Name my-secret -Force

    Removes the specified secret without prompting for confirmation.

.EXAMPLE
    PS> Get-KelvinSecret -Name my-secret | Remove-KelvinSecret -Force

    Removes the secret retrieved via pipeline without prompting for confirmation.
#>
function Remove-KelvinSecret {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        # Secret name(s) to delete.
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidatePattern('^[a-z]([-a-z0-9]*[a-z0-9])?$')]
        [Alias('secret_name')]
        [string[]] $Name,

        # Bypass confirmation prompt.
        [Parameter()]
        [switch] $Force
    )

    process {
        foreach ($s in $Name) {
            if (-not ($Force.IsPresent -or $PSCmdlet.ShouldProcess($s, 'Delete secret'))) {
                continue
            }

            try {
                Invoke-KelvinApi "secrets/$s/delete" -Method Post | Out-Null
            }
            catch {
                Write-Error "Failed to delete secret '$s': $_"
            }
        }
    }
}
