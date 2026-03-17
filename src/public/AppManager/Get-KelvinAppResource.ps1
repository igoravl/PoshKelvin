<#
.SYNOPSIS
    Gets resources for a specific application.

.DESCRIPTION
    Retrieves resources associated with a specific application from the currently
    connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinAppResource -AppName my-app

    Lists all resources for the specified application.

.EXAMPLE
    PS> Get-KelvinAppResource -AppName my-app -Status running

    Lists only the running resources for the specified application.
#>
Function Get-KelvinAppResource {
    [OutputType('Kelvin.AppResource')]
    [CmdletBinding()]
    Param
    (
        # The name of the application to retrieve resources for.
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('app_name')]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [string] $AppName,

        # Free-form text search across resource fields.
        [Parameter()]
        [string[]] $Search,

        # Filter resources by name.
        [Parameter()]
        [string[]] $ResourceName,

        # Filter resources by status.
        [Parameter()]
        [ValidateSet('running', 'stopped', 'unknown')]
        [string[]] $Status
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi "app-manager/app/$AppName/resources/list" -Method Post -TypeName 'Kelvin.AppResource' -Parameters $params `
        | ForEach-Object {
            Write-Output $_
        }
    }
}
