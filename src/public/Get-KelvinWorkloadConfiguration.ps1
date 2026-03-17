<#
.SYNOPSIS
    Gets the configuration of a workload.

.DESCRIPTION
    Retrieves the configuration of a workload from the currently connected
    Kelvin instance.

.EXAMPLE
    PS> Get-KelvinWorkloadConfiguration -Name my-workload

    Returns the configuration for the specified workload.
#>
function Get-KelvinWorkloadConfiguration {
    [CmdletBinding()]
    param (
        # The name of the workload to get the configuration for
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('workload_name')]
        [string] $Name
    )

    process {
        $result = Invoke-KelvinApi "workloads/$Name/configurations/get" -Method Get
        if ($result.PSObject.Properties.Name -contains 'configuration') {
            Write-Output $result.configuration
        }
        else {
            Write-Output $result
        }
    }
}
