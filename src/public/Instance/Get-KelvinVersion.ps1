<#
.SYNOPSIS
    Gets the deployed version of the Kelvin instance.

.DESCRIPTION
    Queries the connected Kelvin instance's status endpoint and returns its
    x-deploy-version response header as a System.Version object.
    Reports an error if the header is missing or is not a valid System.Version.

.EXAMPLE
    PS> Get-KelvinVersion

    Returns the deployed version of the connected instance.
#>
function Get-KelvinVersion {
    [CmdletBinding()]
    [OutputType([System.Version])]
    param()

    $response = Invoke-KelvinApi 'instance/status/get' -Method Get `
        -IncludeHeaders 'x-deploy-version' -ErrorAction Stop
    $versionHeader = $null
    if ($null -ne $response._headers) {
        $versionHeader = $response._headers['x-deploy-version']
    }
    if ([string]::IsNullOrWhiteSpace($versionHeader)) {
        throw 'The instance status response is missing the x-deploy-version header.'
    }

    $version = $null
    if (-not [System.Version]::TryParse($versionHeader, [ref] $version)) {
        throw 'The x-deploy-version response header is not a valid System.Version.'
    }

    $version
}
