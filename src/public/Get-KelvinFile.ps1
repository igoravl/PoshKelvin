<#
.SYNOPSIS
    Gets files from Kelvin file storage.

.DESCRIPTION
    Retrieves files from the currently connected Kelvin instance file storage.

.EXAMPLE
    PS> Get-KelvinFile

    Lists all files in file storage.

.EXAMPLE
    PS> Get-KelvinFile -Type config -Detailed

    Retrieves detailed information for files of type 'config'.
#>
Function Get-KelvinFile {
    [OutputType('Kelvin.File')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across file fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter files by ID.
        [Parameter(ParameterSetName = 'Query')]
        [Alias('file_id')]
        [string[]] $Id,

        # Filter files by name.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Name,

        # Filter files by type.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Type,

        # Return detailed information for each file.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'filestorage/list' -Method Get -TypeName 'Kelvin.File' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "filestorage/$($_.id)/get" -Method Get -TypeName 'Kelvin.File')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
