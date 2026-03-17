<#
.SYNOPSIS
    Gets services from a Kelvin cluster.

.DESCRIPTION
    Retrieves the services from a specific cluster in the currently connected
    Kelvin instance.

.EXAMPLE
    PS> Get-KelvinClusterService -ClusterName my-cluster

    Lists all services in the specified cluster.

.EXAMPLE
    PS> Get-KelvinCluster -Name my-cluster | Get-KelvinClusterService -Status running

    Lists running services for a cluster obtained via pipeline.
#>
Function Get-KelvinClusterService {
    [OutputType('Kelvin.ClusterService')]
    [CmdletBinding()]
    Param
    (
        # The name of the cluster to retrieve services from.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('cluster_name')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [string] $ClusterName,

        # Free-form text search across service fields.
        [Parameter(Position = 1)]
        [string[]] $Search,

        # Filter services by name.
        [Parameter()]
        [string[]] $Name,

        # Filter services by type.
        [Parameter()]
        [string[]] $Type,

        # Filter services by status.
        [Parameter()]
        [ValidateSet('running', 'stopped', 'unknown')]
        [string[]] $Status
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi "orchestration/clusters/$ClusterName/services/list" -Method Get -TypeName 'Kelvin.ClusterService' -Parameters $params `
        | ForEach-Object {
            Write-Output $_
        }
    }
}
