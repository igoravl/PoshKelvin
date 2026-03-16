<#
.SYNOPSIS
    Gets data streams from Kelvin.

.DESCRIPTION
    Retrieves data streams from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinDataStream

    Lists all data streams.

.EXAMPLE
    PS> Get-KelvinDataStream -AssetName my-asset -Detailed

    Retrieves detailed data streams associated with the specified asset.
#>
Function Get-KelvinDataStream {
    [OutputType('Kelvin.DataStream')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across data stream fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter data streams by name.
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('data_stream_name')]
        [string[]] $Name,

        # Filter data streams by data type.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $DataType,

        # Filter data streams by semantic type.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $SemanticType,

        # Filter data streams by associated asset name.
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('asset_name')]
        [string[]] $AssetName,

        # Return detailed information for each data stream.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'datastreams/list' -Method Get -TypeName 'Kelvin.DataStream' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "datastreams/$($_.name)/get" -Method Get -TypeName 'Kelvin.DataStream')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
