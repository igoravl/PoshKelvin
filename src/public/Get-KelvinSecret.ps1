<#
.SYNOPSIS
    Gets secrets from Kelvin.

.DESCRIPTION
    Retrieves secrets from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinSecret

    Lists all secrets.

.EXAMPLE
    PS> Get-KelvinSecret -Name my-secret

    Retrieves a specific secret by name.
#>
Function Get-KelvinSecret {
    [OutputType('Kelvin.Secret')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across secret fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter secrets by name.
        [Parameter(ParameterSetName = 'Query')]
        [Alias('secret_name')]
        [string[]] $Name
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'secrets/list' -Method Get -TypeName 'Kelvin.Secret' -Parameters $params `
        | ForEach-Object {
            Write-Output $_
        }
    }
}
