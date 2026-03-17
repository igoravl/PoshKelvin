<#
.SYNOPSIS
    Gets app manager details for a specific resource.

.DESCRIPTION
    Retrieves app manager details for a specific resource from the currently
    connected Kelvin instance.

.EXAMPLE
    PS> Get-KelvinAppManagerResource -ResourceKrn 'krn:my-resource'

    Retrieves app manager details for the specified resource KRN.
#>
Function Get-KelvinAppManagerResource {
    [OutputType('Kelvin.AppManagerResource')]
    [CmdletBinding()]
    Param
    (
        # The Kelvin Resource Name (KRN) identifier.
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('resource_krn')]
        [string] $ResourceKrn
    )

    Process {
        $params = _GetParams

        Invoke-KelvinApi "app-manager/resource/$ResourceKrn/get" -Method Get -TypeName 'Kelvin.AppManagerResource' -Parameters $params `
        | ForEach-Object {
            Write-Output $_
        }
    }
}
