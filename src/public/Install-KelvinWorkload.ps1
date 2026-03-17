<#
.SYNOPSIS
    Installs (applies) one or more staged workloads.

.DESCRIPTION
    Initiates the final deploy action for workloads that were previously deployed
    with the staged option. Only valid for workloads deployed with staged mode
    and without instant apply.

.EXAMPLE
    PS> Install-KelvinWorkload -Name my-workload

    Applies the staged workload to finalize deployment.

.EXAMPLE
    PS> Install-KelvinWorkload -Name wl-a, wl-b

    Applies multiple staged workloads at once.
#>
function Install-KelvinWorkload {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        # Staged workload name(s) to apply
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('workload_names')]
        [string[]] $Name
    )

    process {
        if (-not $PSCmdlet.ShouldProcess(($Name -join ', '), 'Apply staged workloads')) {
            return
        }

        $body = @{
            workload_names = $Name
        }

        try {
            Invoke-KelvinApi 'workloads/apply' -Method Post -Body $body | Out-Null
        }
        catch {
            Write-Error "Failed to apply staged workloads: $_"
        }
    }
}
