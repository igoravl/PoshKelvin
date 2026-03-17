<#
.SYNOPSIS
    Gets logs for a workload.

.DESCRIPTION
    Retrieves the logs of a workload from the currently connected Kelvin instance.
    Supports filtering by number of recent lines or by start time.

.EXAMPLE
    PS> Get-KelvinWorkloadLog -Name my-workload

    Returns all available logs for the specified workload.

.EXAMPLE
    PS> Get-KelvinWorkloadLog -Name my-workload -TailLines 100

    Returns the last 100 log lines for the specified workload.

.EXAMPLE
    PS> Get-KelvinWorkloadLog -Name my-workload -SinceTime (Get-Date).AddHours(-1)

    Returns logs generated in the last hour.
#>
function Get-KelvinWorkloadLog {
    [CmdletBinding()]
    param (
        # The name of the workload to get logs for
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('workload_name')]
        [string] $Name,

        # Number of most recent log lines to retrieve
        [Parameter()]
        [Alias('tail_lines')]
        [int] $TailLines,

        # UTC start time for the log retrieval window
        [Parameter()]
        [Alias('since_time')]
        [datetime] $SinceTime
    )

    process {
        $params = @{}
        if ($PSBoundParameters.ContainsKey('TailLines')) {
            $params['tail_lines'] = $TailLines
        }
        if ($PSBoundParameters.ContainsKey('SinceTime')) {
            $params['since_time'] = $SinceTime.ToUniversalTime().ToString('o')
        }

        $result = Invoke-KelvinApi "workloads/$Name/logs/get" -Method Get -Parameters $params
        if ($result.PSObject.Properties.Name -contains 'logs') {
            Write-Output $result.logs
        }
        else {
            Write-Output $result
        }
    }
}
