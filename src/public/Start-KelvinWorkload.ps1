<#
.SYNOPSIS
    Starts one or more workloads.

.DESCRIPTION
    Starts one or more workloads on the currently connected Kelvin instance.

.EXAMPLE
    PS> Start-KelvinWorkload -Name my-workload

    Starts the specified workload.

.EXAMPLE
    PS> Get-KelvinWorkload -ClusterName my-cluster | Start-KelvinWorkload

    Starts all workloads in the specified cluster via pipeline input.
#>
function Start-KelvinWorkload {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        # Workload name(s) to start
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('workload_name')]
        [string[]] $Name
    )

    process {
        foreach ($w in $Name) {
            if (-not $PSCmdlet.ShouldProcess($w, 'Start workload')) {
                continue
            }

            try {
                Invoke-KelvinApi "workloads/$w/start" -Method Get | Out-Null
            }
            catch {
                Write-Error "Failed to start workload '$w': $_"
            }
        }
    }
}
