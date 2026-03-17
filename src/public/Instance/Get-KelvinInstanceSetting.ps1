<#
.SYNOPSIS
    Gets instance settings from Kelvin.

.DESCRIPTION
    Retrieves instance settings from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinInstanceSetting

    Lists all instance settings.

.EXAMPLE
    PS> Get-KelvinInstanceSetting -Name my-setting -Detailed

    Retrieves detailed information for a specific setting.
#>
Function Get-KelvinInstanceSetting {
    [OutputType('Kelvin.InstanceSetting')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across setting fields.
        [Parameter(Position = 0)]
        [string[]] $Search,

        # Filter settings by name.
        [Parameter()]
        [Alias('setting_name')]
        [string[]] $Name,

        # Return detailed information for each setting.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'instance/settings/list' -Method Get -TypeName 'Kelvin.InstanceSetting' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent -and $_.name) {
                $ret = (Invoke-KelvinApi "instance/settings/$($_.name)/get" -Method Get -TypeName 'Kelvin.InstanceSetting')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
