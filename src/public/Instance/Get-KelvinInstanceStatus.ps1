<#
.SYNOPSIS
    Gets the status of the Kelvin instance.

.DESCRIPTION
    Retrieves the current status of the connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinInstanceStatus

    Returns the current instance status.
#>
Function Get-KelvinInstanceStatus {
    [OutputType('Kelvin.InstanceStatus')]
    [CmdletBinding()]
    Param()

    Process {
        $params = _GetParams

        Invoke-KelvinApi "instance/status/get" -Method Get -TypeName 'Kelvin.InstanceStatus' -Parameters $params `
        | ForEach-Object {
            Write-Output $_
        }
    }
}
