<#
.SYNOPSIS
    Gets recommendation types from Kelvin.

.DESCRIPTION
    Retrieves recommendation types from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinRecommendationType

    Lists all recommendation types.

.EXAMPLE
    PS> Get-KelvinRecommendationType -Name my-type -Detailed

    Retrieves detailed information for a specific recommendation type.
#>
Function Get-KelvinRecommendationType {
    [OutputType('Kelvin.RecommendationType')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across recommendation type fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter recommendation types by name.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Name,

        # Return detailed information for each recommendation type.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'recommendations/types/list' -Method Get -TypeName 'Kelvin.RecommendationType' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "recommendations/types/$($_.name)/get" -Method Get -TypeName 'Kelvin.RecommendationType')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
