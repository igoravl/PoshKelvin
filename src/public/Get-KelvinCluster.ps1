<#
.SYNOPSIS
    Gets clusters from Kelvin.

.DESCRIPTION
    Retrieves clusters from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinCluster

    Lists all clusters.

.EXAMPLE
    PS> Get-KelvinCluster -Status online -Detailed

    Retrieves detailed information for all online clusters.
#>
Function Get-KelvinCluster {
    [OutputType('Kelvin.Cluster')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across cluster fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter clusters by name.
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('names')]
        [string[]] $Name,

        # Filter clusters by readiness state.
        [Parameter(ParameterSetName = 'Query')]
        [bool] $Ready,

        # Filter clusters by type.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Type,

        # Filter clusters by status.
        [Parameter(ParameterSetName = 'Query')]
        [ValidateSet('pending_provision', 'pending', 'online', 'unreachable', 'requires_attention')]
        [string[]] $Status,

        # Return detailed information for each cluster.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'orchestration/clusters/list' -Method Get -TypeName 'Kelvin.Cluster' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "orchestration/clusters/$($_.name)/get" -Method Get -TypeName 'Kelvin.Cluster')
            }
            else {
                $ret = $_
            }
            Write-Output ($ret | Add-Member -Name 'cluster_name' -Value $ret.name -MemberType NoteProperty -PassThru)
        }
    }
}
