<#
.SYNOPSIS
    Gets data stream semantic types from Kelvin.

.DESCRIPTION
    Retrieves data stream semantic types from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinDataStreamSemanticType

    Lists all data stream semantic types.

.EXAMPLE
    PS> Get-KelvinDataStreamSemanticType -Name temperature -Detailed

    Retrieves detailed information for the 'temperature' semantic type.
#>
Function Get-KelvinDataStreamSemanticType {
    [OutputType('Kelvin.DataStreamSemanticType')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across semantic type fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter semantic types by name.
        [Parameter(ParameterSetName = 'Query')]
        [Alias('semantic_type_name')]
        [string[]] $Name,

        # Return detailed information for each semantic type.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'datastreams/semantic-types/list' -Method Get -TypeName 'Kelvin.DataStreamSemanticType' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "datastreams/semantic-types/$($_.name)/get" -Method Get -TypeName 'Kelvin.DataStreamSemanticType')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
