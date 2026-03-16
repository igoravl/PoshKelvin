<#
.SYNOPSIS
    Gets bridges from Kelvin.

.DESCRIPTION
    Retrieves bridges from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinBridge

    Lists all bridges.

.EXAMPLE
    PS> Get-KelvinBridge -Running $true -Detailed

    Retrieves detailed information for all running bridges.
#>
Function Get-KelvinBridge {
    [OutputType('Kelvin.Bridge')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across bridge fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter bridges by name.
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('bridge_name')]
        [string[]] $Name,

        # Filter bridges by running state.
        [Parameter(ParameterSetName = 'Query')]
        [bool] $Running,

        # Return detailed information for each bridge.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'bridges/list' -Method Get -TypeName 'Kelvin.Bridge' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "bridges/$($_.name)/get" -Method Get -TypeName 'Kelvin.Bridge')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
