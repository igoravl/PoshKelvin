<#
.SYNOPSIS
    Updates the configuration of a workload.

.DESCRIPTION
    Updates the configuration of a workload on the currently connected Kelvin
    instance. Use the Configuration parameter to pass a hashtable with the
    desired settings, or the Body parameter for advanced scenarios.

    WARNING: Sending an empty configuration object will remove all configurations.

.EXAMPLE
    PS> Set-KelvinWorkloadConfiguration -Name my-workload -Configuration @{ key1 = 'value1' }

    Updates the configuration for the specified workload.

.EXAMPLE
    PS> Set-KelvinWorkloadConfiguration -Name my-workload -Body @{ configuration = @{ key1 = 'value1' } }

    Updates the configuration using a raw body hashtable.
#>
function Set-KelvinWorkloadConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Properties')]
    param (
        # The name of the workload to update the configuration for
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('workload_name')]
        [string] $Name,

        # The configuration hashtable to set on the workload
        [Parameter(Mandatory = $true, ParameterSetName = 'Properties')]
        [hashtable] $Configuration,

        # A raw request body hashtable, passed directly to the API
        [Parameter(Mandatory = $true, ParameterSetName = 'Body')]
        [hashtable] $Body
    )

    process {
        if (-not $PSCmdlet.ShouldProcess($Name, 'Update workload configuration')) {
            return
        }

        $requestBody = if ($PSCmdlet.ParameterSetName -eq 'Body') {
            $Body
        }
        else {
            @{ configuration = $Configuration }
        }

        try {
            $result = Invoke-KelvinApi "workloads/$Name/configurations/update" -Method Post -Body $requestBody
            if ($result.PSObject.Properties.Name -contains 'configuration') {
                Write-Output $result.configuration
            }
            else {
                Write-Output $result
            }
        }
        catch {
            Write-Error "Failed to update configuration for workload '$Name': $_"
        }
    }
}
