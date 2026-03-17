<#
.SYNOPSIS
    Gets threads from Kelvin.

.DESCRIPTION
    Retrieves threads from the currently connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinThread

    Lists all threads.

.EXAMPLE
    PS> Get-KelvinThread -Title 'my-thread' -Detailed

    Retrieves detailed information for threads matching the specified title.
#>
Function Get-KelvinThread {
    [OutputType('Kelvin.Thread')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across thread fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter threads by ID.
        [Parameter(ParameterSetName = 'Query')]
        [Alias('thread_id')]
        [string[]] $Id,

        # Filter threads by title.
        [Parameter(ParameterSetName = 'Query')]
        [string[]] $Title,

        # Return detailed information for each thread.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'threads/list' -Method Get -TypeName 'Kelvin.Thread' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "threads/$($_.id)/get" -Method Get -TypeName 'Kelvin.Thread')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
