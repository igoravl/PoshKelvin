<#
.SYNOPSIS
    Gets nodes from a Kelvin cluster.

.DESCRIPTION
    Retrieves the nodes from a specific cluster in the currently connected
    Kelvin instance.

.EXAMPLE
    PS> Get-KelvinClusterNode -ClusterName my-cluster

    Lists all nodes in the specified cluster.

.EXAMPLE
    PS> Get-KelvinCluster -Name my-cluster | Get-KelvinClusterNode -Status online

    Lists online nodes for a cluster obtained via pipeline.
#>
Function Get-KelvinClusterNode {
    [OutputType('Kelvin.ClusterNode')]
    [CmdletBinding()]
    Param
    (
        # The name of the cluster to retrieve nodes from.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('cluster_name')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [string] $ClusterName,

        # Free-form text search across node fields.
        [Parameter(Position = 1)]
        [string[]] $Search,

        # Filter nodes by name.
        [Parameter()]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('node_name', 'names')]
        [string[]] $Name,

        # Filter nodes by status.
        [Parameter()]
        [ValidateSet('online', 'offline', 'unknown')]
        [string[]] $Status,

        # Return detailed information for each node.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi "orchestration/clusters/$ClusterName/nodes/list" -Method Get -TypeName 'Kelvin.ClusterNode' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "orchestration/clusters/$ClusterName/nodes/$($_.name)/get" -Method Get -TypeName 'Kelvin.ClusterNode')
            }
            else {
                $ret = $_
            }
            Write-Output ($ret | Add-Member -Name 'node_name' -Value $ret.name -MemberType NoteProperty -PassThru)
        }
    }
}
