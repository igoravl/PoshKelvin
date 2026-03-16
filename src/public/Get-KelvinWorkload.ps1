<#
.SYNOPSIS
    Gets workloads from Kelvin.

.DESCRIPTION
    Retrieves a list of workloads from the currently connected Kelvin instance.
    Supports filtering by name, application, cluster, node, status, and more.

.EXAMPLE
    PS> Get-KelvinWorkload

    Lists all workloads.

.EXAMPLE
    PS> Get-KelvinWorkload -ClusterName my-cluster

    Lists workloads deployed to the specified cluster.

.EXAMPLE
    PS> Get-KelvinWorkload -Name my-app -Detailed

    Retrieves detailed information for a specific workload.

.EXAMPLE
    PS> Get-KelvinWorkload -AppName my-app -DownloadStatus ready

    Lists workloads for an application that are ready to run.
#>
Function Get-KelvinWorkload {
    [CmdletBinding()]
    [OutputType('Kelvin.Workload')]
    Param 
    (
        # Free-form text search across workload fields
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter workloads by name
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('workload_name')]
        [string[]] $Name,

        # Filter workloads by application name
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('app_name')]
        [string[]] $AppName,

        # Filter workloads by application version
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('app_version')]
        [string[]] $AppVersion,

        # Filter workloads by cluster name
        [Parameter(ParameterSetName = 'Query', ValueFromPipelineByPropertyName = $true)]
        [Alias('cluster_name')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [string[]] $ClusterName,

        # Filter workloads by node name
        [Parameter(ParameterSetName = 'Query')]
        [Alias('node_name')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [string[]] $NodeName,

        # Filter workloads by enabled status
        [Parameter(ParameterSetName = 'Query')]
        [bool] $Enabled,

        # Filter workloads by associated asset name
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('asset_name')]
        [string] $AssetName,

        # Filter workloads by staged status
        [Parameter(ParameterSetName = 'Query')]
        [bool] $Staged,

        # Filter workloads by download status: pending, scheduled, processing, ready, or failed
        [Parameter(ParameterSetName = 'Query')]
        [ValidateSet('pending', 'scheduled', 'processing', 'ready', 'failed')]
        [Alias('download_status')]
        [string[]] $DownloadStatus,

        # Return detailed workload information by making an additional API call for each workload
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams $PSBoundParameters @{
            search          = $Search
            app_name        = $AppName
            app_version     = $AppVersion
            cluster_name    = $ClusterName
            node_name       = $NodeName
            enabled         = $Enabled
            asset_name      = $AssetName
            staged          = $Staged
            download_status = $DownloadStatus
        }

        # Call the Kelvin API to list workloads
        Invoke-KelvinApi 'workloads/list' -Method Get -TypeName 'Kelvin.Workload' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "workloads/$($_.name)/get" -Method Get -TypeName 'Kelvin.Workload')
            }
            else {
                $ret = $_
            }
            Write-Output $ret | Add-Member -Name 'state' -Value $_.status.state -MemberType NoteProperty -PassThru
        }
    }
}
