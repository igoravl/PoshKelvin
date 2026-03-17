<#
.SYNOPSIS
    Stops one or more workloads.

.DESCRIPTION
    Stops one or more running workloads on the currently connected Kelvin instance.

.EXAMPLE
    PS> Stop-KelvinWorkload -Name my-workload

    Stops the specified workload.

.EXAMPLE
    PS> Get-KelvinWorkload -ClusterName my-cluster | Stop-KelvinWorkload

    Stops all workloads in the specified cluster via pipeline input.
#>
function Stop-KelvinWorkload {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        # Workload name(s) to stop
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('workload_name')]
        [string[]] $Name
    )

    process {
        foreach ($w in $Name) {
            if (-not $PSCmdlet.ShouldProcess($w, 'Stop workload')) {
                continue
            }

            try {
                Invoke-KelvinApi "workloads/$w/stop" -Method Get | Out-Null
            }
            catch {
                Write-Error "Failed to stop workload '$w': $_"
            }
        }
    }
}
