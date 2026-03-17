<#
.SYNOPSIS
    Gets parameter definitions from Kelvin.

.DESCRIPTION
    Retrieves parameter definitions from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinParameterDefinition

    Lists all parameter definitions.

.EXAMPLE
    PS> Get-KelvinParameterDefinition -Type string

    Lists parameter definitions of type 'string'.
#>
Function Get-KelvinParameterDefinition {
    [OutputType('Kelvin.ParameterDefinition')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across parameter definition fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter parameter definitions by name.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Name,

        # Filter parameter definitions by type.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Type
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'parameters/definitions/list' -Method Get -TypeName 'Kelvin.ParameterDefinition' -Parameters $params `
        | ForEach-Object {
            Write-Output $_
        }
    }
}
