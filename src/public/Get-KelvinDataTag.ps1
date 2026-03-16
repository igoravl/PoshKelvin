<#
.SYNOPSIS
    Gets data tags from Kelvin.

.DESCRIPTION
    Retrieves data tags from the currently connected Kelvin instance. Supports
    querying either data tag instances or tag definitions via the -Tags switch.

.EXAMPLE
    PS> Get-KelvinDataTag

    Lists all data tag instances.

.EXAMPLE
    PS> Get-KelvinDataTag -Tags

    Lists all tag definitions.

.EXAMPLE
    PS> Get-KelvinDataTag -Tags -TagName my-tag -Detailed

    Retrieves detailed information for a specific tag definition.
#>
Function Get-KelvinDataTag {
    [OutputType('Kelvin.DataTag')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across data tag fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter data tags by ID.
        [Parameter(ParameterSetName = 'Query')]
        [Alias('datatag_id')]
        [string[]] $Id,

        # When specified, queries tag definitions instead of data tag instances.
        [Parameter(ParameterSetName = 'Tags')]
        [switch] $Tags,

        # Filter tag definitions by name (used with -Tags).
        [Parameter(ParameterSetName = 'Tags')]
        [Alias('tag_name')]
        [string[]] $TagName,

        # Return detailed information for each result.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        if ($Tags.IsPresent) {
            $endpoint = 'datatags/tags/list'
            $detailEndpoint = "datatags/tags/{0}/get"
            $idProperty = "name"
        }
        else {
            $endpoint = 'datatags/list'
            $detailEndpoint = "datatags/{0}/get"
            $idProperty = "id"
        }

        Invoke-KelvinApi $endpoint -Method Get -TypeName 'Kelvin.DataTag' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi ($detailEndpoint -f $_.$idProperty) -Method Get -TypeName 'Kelvin.DataTag')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
