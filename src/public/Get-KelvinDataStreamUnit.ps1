<#
.SYNOPSIS
    Gets data stream units from Kelvin.

.DESCRIPTION
    Retrieves data stream units from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinDataStreamUnit

    Lists all data stream units.

.EXAMPLE
    PS> Get-KelvinDataStreamUnit -Name celsius -Detailed

    Retrieves detailed information for the 'celsius' unit.
#>
Function Get-KelvinDataStreamUnit {
    [OutputType('Kelvin.DataStreamUnit')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across unit fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter units by name.
        [Parameter(ParameterSetName = 'Query')]
        [Alias('unit_name')]
        [string[]] $Name,

        # Return detailed information for each unit.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'datastreams/units/list' -Method Get -TypeName 'Kelvin.DataStreamUnit' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "datastreams/units/$($_.name)/get" -Method Get -TypeName 'Kelvin.DataStreamUnit')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
