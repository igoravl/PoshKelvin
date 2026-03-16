<#
.SYNOPSIS
    Gets asset types from Kelvin.

.DESCRIPTION
    Retrieves asset types from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinAssetType

    Lists all asset types.

.EXAMPLE
    PS> Get-KelvinAssetType -Name pump -Detailed

    Retrieves detailed information for the 'pump' asset type.
#>
Function Get-KelvinAssetType {
    [OutputType('Kelvin.AssetType')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across asset type fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter asset types by name.
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('asset_type_name')]
        [string[]] $Name,

        # Return detailed information for each asset type.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'assets/types/list' -Method Get -TypeName 'Kelvin.AssetType' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "assets/types/$($_.name)/get" -Method Get -TypeName 'Kelvin.AssetType')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
