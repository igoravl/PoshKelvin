<#
.SYNOPSIS
    Updates (replaces) an existing secret in Kelvin.

.DESCRIPTION
    Replaces the value of an existing secret on the currently connected Kelvin
    instance by removing the current secret and creating a new one with the
    same name and the new value. Because the Kelvin API does not support
    in-place updates, this cmdlet performs a delete followed by a create.

.EXAMPLE
    PS> Set-KelvinSecret -Name my-secret -Value 'NewP@ssw0rd!'

    Replaces the value of the secret 'my-secret' after confirmation.

.EXAMPLE
    PS> Set-KelvinSecret -Name my-secret -Value 'NewP@ssw0rd!' -Force

    Replaces the value of the secret 'my-secret' without prompting for confirmation.
#>
function Set-KelvinSecret {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType('Kelvin.Secret')]
    param (
        # Unique identifier name of the secret to update.
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidatePattern('^[a-z]([-a-z0-9]*[a-z0-9])?$')]
        [ValidateLength(1, 32)]
        [Alias('secret_name')]
        [string] $Name,

        # The new secret value.
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 64000)]
        [string] $Value,

        # Bypass confirmation prompt.
        [Parameter()]
        [switch] $Force
    )

    process {
        if (-not ($Force.IsPresent -or $PSCmdlet.ShouldProcess($Name, 'Replace secret (delete + create)'))) {
            return
        }

        try {
            Invoke-KelvinApi "secrets/$Name/delete" -Method Post | Out-Null
        }
        catch {
            Write-Error "Failed to delete existing secret '$Name': $_"
            return
        }

        try {
            $requestBody = @{
                name  = $Name
                value = $Value
            }
            $result = Invoke-KelvinApi 'secrets/create' -Method Post -Body $requestBody -TypeName 'Kelvin.Secret'
            Write-Output $result
        }
        catch {
            Write-Error "Failed to create secret '$Name' after deletion: $_"
        }
    }
}
