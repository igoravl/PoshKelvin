<#
.SYNOPSIS
    Creates a new workload on a cluster.

.DESCRIPTION
    Deploys an application from the App Registry as a new workload to a cluster
    or node on the currently connected Kelvin instance. Use individual parameters
    for common scenarios, or the Body parameter for advanced payloads.

.EXAMPLE
    PS> New-KelvinWorkload -AppName my-app -ClusterName my-cluster

    Creates a workload from the latest version of the application on the specified cluster.

.EXAMPLE
    PS> New-KelvinWorkload -AppName my-app -AppVersion 1.2.0 -ClusterName my-cluster -Name my-workload -Staged

    Creates a staged workload from a specific application version with a custom name.

.EXAMPLE
    PS> New-KelvinWorkload -Body @{ app_name = 'my-app'; cluster_name = 'my-cluster'; payload = @{ inputs = @{} } }

    Creates a workload using a raw body hashtable for advanced scenarios.
#>
function New-KelvinWorkload {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Properties')]
    [OutputType('Kelvin.Workload')]
    param (
        # The application name from the App Registry to deploy
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'Properties')]
        [ValidatePattern('^[a-z]([-a-z0-9]*[a-z0-9])?$')]
        [Alias('app_name')]
        [string] $AppName,

        # A unique name for the workload (auto-generated if not specified)
        [Parameter(ParameterSetName = 'Properties')]
        [ValidatePattern('^[a-z]([-a-z0-9]*[a-z0-9])?$')]
        [ValidateLength(1, 32)]
        [string] $Name,

        # A display title for the workload
        [Parameter(ParameterSetName = 'Properties')]
        [string] $Title,

        # The version of the application to deploy
        [Parameter(ParameterSetName = 'Properties')]
        [Alias('app_version')]
        [string] $AppVersion,

        # The target cluster name to deploy the workload to
        [Parameter(ParameterSetName = 'Properties')]
        [ValidatePattern('^[a-z]([-a-z0-9]*[a-z0-9])?$')]
        [Alias('cluster_name')]
        [string] $ClusterName,

        # Application parameters (inputs, outputs, info, spec version, system)
        [Parameter(ParameterSetName = 'Properties')]
        [hashtable] $Payload,

        # If specified, applies the deploy immediately without requiring a separate Install call
        [Parameter(ParameterSetName = 'Properties')]
        [Alias('instantly_apply')]
        [switch] $InstantlyApply,

        # If specified, Kelvin handles deploy with pre-download
        [Parameter(ParameterSetName = 'Properties')]
        [switch] $Staged,

        # Who or what initiated the deploy (KRN format)
        [Parameter(ParameterSetName = 'Properties')]
        [string] $Source,

        # A raw request body hashtable, passed directly to the API
        [Parameter(Mandatory = $true, ParameterSetName = 'Body')]
        [hashtable] $Body
    )

    process {
        $requestBody = if ($PSCmdlet.ParameterSetName -eq 'Body') {
            $Body
        }
        else {
            $b = @{ app_name = $AppName }
            if ($PSBoundParameters.ContainsKey('Name'))           { $b['name']            = $Name }
            if ($PSBoundParameters.ContainsKey('Title'))          { $b['title']           = $Title }
            if ($PSBoundParameters.ContainsKey('AppVersion'))     { $b['app_version']     = $AppVersion }
            if ($PSBoundParameters.ContainsKey('ClusterName'))    { $b['cluster_name']    = $ClusterName }
            if ($PSBoundParameters.ContainsKey('Payload'))        { $b['payload']         = $Payload }
            if ($InstantlyApply.IsPresent)                        { $b['instantly_apply'] = $true }
            if ($Staged.IsPresent)                                { $b['staged']          = $true }
            if ($PSBoundParameters.ContainsKey('Source'))         { $b['source']          = $Source }
            $b
        }

        $target = if ($requestBody.ContainsKey('name') -and $requestBody['name']) {
            $requestBody['name']
        }
        elseif ($requestBody.ContainsKey('app_name') -and $requestBody['app_name']) {
            $requestBody['app_name']
        }
        else {
            '<unspecified workload>'
        }
        if (-not $PSCmdlet.ShouldProcess($target, 'Create workload')) {
            return
        }

        try {
            $result = Invoke-KelvinApi 'workloads/deploy' -Method Post -Body $requestBody -TypeName 'Kelvin.Workload'
            Write-Output $result
        }
        catch {
            Write-Error "Failed to create workload: $_"
        }
    }
}
