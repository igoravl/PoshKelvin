<#
.SYNOPSIS
    Gets data types from Kelvin.

.DESCRIPTION
    Retrieves data types from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinDataType

    Lists all data types.

.EXAMPLE
    PS> Get-KelvinDataType -Name float

    Retrieves information for the 'float' data type.
#>
Function Get-KelvinDataType {
    [OutputType('Kelvin.DataType')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across data type fields.
        [Parameter(Position = 0)]
        [string[]] $Search,

        # Filter data types by name.
        [Parameter()]
        [string[]] $Name
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'datastreams/data-types/list' -Method Get -TypeName 'Kelvin.DataType' -Parameters $params `
        | ForEach-Object {
            Write-Output $_
        }
    }
}
