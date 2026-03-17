<#
.SYNOPSIS
    Gets recommendations from Kelvin.

.DESCRIPTION
    Retrieves recommendations from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinRecommendation

    Lists all recommendations.

.EXAMPLE
    PS> Get-KelvinRecommendation -Status pending -Detailed

    Retrieves detailed information for all pending recommendations.
#>
Function Get-KelvinRecommendation {
    [OutputType('Kelvin.Recommendation')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across recommendation fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter recommendations by ID.
        [Parameter(ParameterSetName = 'Query')]
        [Alias('recommendation_id')]
        [string[]] $Id,

        # Filter recommendations by type.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Type,

        # Filter recommendations by status.
        [Parameter(ParameterSetName = 'Query')]
        [ValidateSet('accepted', 'rejected', 'pending')]
        [string[]] $Status,

        # Return detailed information for each recommendation.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'recommendations/list' -Method Get -TypeName 'Kelvin.Recommendation' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "recommendations/$($_.id)/get" -Method Get -TypeName 'Kelvin.Recommendation')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
