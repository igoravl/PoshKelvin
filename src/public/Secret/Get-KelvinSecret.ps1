<#
.SYNOPSIS
    Gets secrets from Kelvin.

.DESCRIPTION
    Retrieves secrets from the currently connected Kelvin instance.
    Lists use parsed streaming by default. Use PaginationMode to select cursor
    or limits pagination instead.

.EXAMPLE
    PS> Get-KelvinSecret

    Lists all secrets.

.EXAMPLE
    PS> Get-KelvinSecret -PaginationMode Cursor

    Lists secrets using cursor pagination instead of streaming.

.EXAMPLE
    PS> Get-KelvinSecret -Name my-secret

    Retrieves a specific secret by name.
#>
Function Get-KelvinSecret {
    [OutputType('Kelvin.Secret')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across secret fields.
        [Parameter(Position = 0, ParameterSetName = 'Query')]
        [string[]] $Search,

        # Filter secrets by name.
        [Parameter(ParameterSetName = 'Query')]
        [Alias('secret_name')]
        [string[]] $Name,

        # Select list pagination. Stream emits parsed objects as they arrive.
        [Parameter()]
        [ValidateSet('Cursor', 'Limits', 'Stream')]
        [string] $PaginationMode = 'Stream'
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi 'secrets/list' -Method Get -TypeName 'Kelvin.Secret' -Parameters $params -PaginationMode $PaginationMode `
        | ForEach-Object {
            Write-Output $_
        }
    }
}
