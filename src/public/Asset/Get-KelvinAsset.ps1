<#
.SYNOPSIS
    Gets assets from Kelvin.

.DESCRIPTION
    Retrieves assets from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinAsset

    Lists all assets.

.EXAMPLE
    PS> Get-KelvinAsset -AssetType pump -Status online -Detailed

    Retrieves detailed information for online assets of type 'pump'.
#>
Function Get-KelvinAsset {
    [OutputType('Kelvin.Asset')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across asset fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter assets by name.
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('names')]
        [string[]] $Name,

        # Filter assets by asset type.
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('asset_type')]
        [string[]] $AssetType,

        # Filter assets by status.
        [Parameter(ParameterSetName = 'Query')]
        [ValidateSet('online', 'offline', 'unknown')]
        [string[]] $Status,

        # Return detailed information for each asset.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'assets/list' -Method Get -TypeName 'Kelvin.Asset' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "assets/$($_.name)/get" -Method Get -TypeName 'Kelvin.Asset')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
