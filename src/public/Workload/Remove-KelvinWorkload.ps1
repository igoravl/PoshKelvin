<#
.SYNOPSIS
    Removes (undeploys) one or more workloads.

.DESCRIPTION
    Undeploys one or more workloads from the currently connected Kelvin instance.
    By default, prompts for confirmation before each removal.

.EXAMPLE
    PS> Remove-KelvinWorkload -Name my-workload

    Removes the specified workload after confirmation.

.EXAMPLE
    PS> Remove-KelvinWorkload -Name my-workload -Force

    Removes the specified workload without prompting for confirmation.

.EXAMPLE
    PS> Get-KelvinWorkload -ClusterName my-cluster | Remove-KelvinWorkload -Force

    Removes all workloads in the specified cluster via pipeline input.
#>
function Remove-KelvinWorkload {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType('Kelvin.Workload')]
    param (
        # Workload name(s) to undeploy
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('workload_name')]
        [string[]] $Name,

        # If true, undeploy the staged instance
        [Parameter()]
        [bool] $Staged,

        # Bypass confirmation prompt
        [Parameter()]
        [switch] $Force
    )

    process {
        foreach ($w in $Name) {
            $target = $w
            $action = "Undeploy workload"

            if (-not ($Force.IsPresent -or $PSCmdlet.ShouldProcess($target, $action))) {
                continue
            }

            $params = @{}
            if ($PSBoundParameters.ContainsKey('Staged')) {
                $params['staged'] = $Staged
            }

            try {
                Invoke-KelvinApi "workloads/$w/undeploy" -Method Post -Parameters $params | Out-Null
            }
            catch {
                Write-Error "Failed to undeploy workload '$w': $_"
            }
        }
    }
}
