<#
.SYNOPSIS
    Creates a new secret in Kelvin.

.DESCRIPTION
    Creates a new secret on the currently connected Kelvin instance.
    Once created, the secret value cannot be changed or retrieved via the API;
    it can only be consumed by an App.

.EXAMPLE
    PS> New-KelvinSecret -Name my-secret -Value 'P@ssw0rd!'

    Creates a new secret named 'my-secret' with the specified value.
#>
function New-KelvinSecret {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType('Kelvin.Secret')]
    param (
        # Unique identifier name for the secret.
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidatePattern('^[a-z]([-a-z0-9]*[a-z0-9])?$')]
        [ValidateLength(1, 32)]
        [Alias('secret_name')]
        [string] $Name,

        # The secret value. Once set, it cannot be changed or viewed via the API.
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 64000)]
        [string] $Value
    )

    process {
        if (-not $PSCmdlet.ShouldProcess($Name, 'Create secret')) {
            return
        }

        $requestBody = @{
            name  = $Name
            value = $Value
        }

        try {
            $result = Invoke-KelvinApi 'secrets/create' -Method Post -Body $requestBody -TypeName 'Kelvin.Secret'
            Write-Output $result
        }
        catch {
            Write-Error "Failed to create secret '$Name': $_"
        }
    }
}
