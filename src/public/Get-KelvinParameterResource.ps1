<#
.SYNOPSIS
    Gets parameter resources from Kelvin.

.DESCRIPTION
    Retrieves parameter resources from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinParameterResource

    Lists all parameter resources.

.EXAMPLE
    PS> Get-KelvinParameterResource -ResourceName my-resource

    Retrieves a specific parameter resource by name.
#>
Function Get-KelvinParameterResource {
    [OutputType('Kelvin.ParameterResource')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across parameter resource fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter parameter resources by name.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Name,

        # Filter parameter resources by resource name.
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('resource_name')]
        [string[]] $ResourceName
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'parameters/resources/list' -Method Get -TypeName 'Kelvin.ParameterResource' -Parameters $params `
        | ForEach-Object {
            Write-Output $_
        }
    }
}
