<#
.SYNOPSIS
    Gets applications from the App Registry.

.DESCRIPTION
    Retrieves application information from the currently connected Kelvin instance
    App Registry.
    Lists use parsed streaming by default. Use PaginationMode to select cursor
    or limits pagination instead. Detailed lookups remain separate requests.

.EXAMPLE
    PS> Get-KelvinApp

    Lists all registered applications.

.EXAMPLE
    PS> Get-KelvinApp -PaginationMode Cursor

    Lists applications using cursor pagination instead of streaming.

.EXAMPLE
    PS> Get-KelvinApp -Name my-app -Detailed

    Retrieves detailed information for a specific application.
#>
Function Get-KelvinApp {
    [OutputType('Kelvin.App')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across application fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter applications by name.
        [Parameter(ParameterSetName = 'Query')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [string[]] $Name,

        # Filter applications by type.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Type,

        # Select list pagination. Stream emits parsed objects as they arrive.
        [Parameter()]
        [ValidateSet('Cursor', 'Limits', 'Stream')]
        [string] $PaginationMode = 'Stream',

        # Return detailed information for each application.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'appregistry/list' -Method Get -TypeName 'Kelvin.App' -Parameters $params -PaginationMode $PaginationMode `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "appregistry/$($_.name)/get" -Method Get -TypeName 'Kelvin.App')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
