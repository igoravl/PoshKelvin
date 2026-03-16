<#
.SYNOPSIS
    Downloads (exports) a workload package.

.DESCRIPTION
    Downloads a workload package (a ZIP file containing the workload binaries and
    manifest files) from the Kelvin API. The package can be saved to a local path
    or returned as a stream for further processing.

.EXAMPLE
    PS> Export-KelvinWorkload -Name my-workload

    Downloads the workload package to the current directory as my-workload.zip.

.EXAMPLE
    PS> Export-KelvinWorkload -Name my-workload -DestinationPath C:\packages

    Downloads the workload package to the specified directory.

.EXAMPLE
    PS> $stream = Export-KelvinWorkload -Name my-workload -AsStream

    Returns the raw response stream for custom processing.
#>
function Export-KelvinWorkload {
    [CmdletBinding(DefaultParameterSetName = 'File')]
    param 
    (
        # The name of the workload to download.
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidatePattern('^[a-z0-9][-_.a-z0-9]*[a-z0-9]$')]
        [Alias('workload_name')]
        [string] $Name,

        # The local directory to save the downloaded package. Defaults to the current directory.
        [Parameter(ParameterSetName = 'File')]
        [string] $DestinationPath = '.',

        # When specified, returns the raw response stream instead of saving to a file.
        [Parameter(ParameterSetName = 'Stream', Mandatory = $true)]
        [switch] $AsStream
    )

    process {
        $params = @{
            workload_name = $Name
        }

        $stream = Invoke-KelvinApi "workloads/$Name/download" -Method Get -TypeName 'Kelvin.Workload' -Parameters $params -ContentType 'application/zip' -AsStream

        if ($AsStream) {
            return $stream
        }

        if (-not (Test-Path -Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory | Out-Null
        }

        $fileName = Join-Path $DestinationPath "${Name}.zip"

        Write-Verbose "Saving workload package to $fileName"

        $fileStream = [System.IO.File]::Create($fileName)
        $stream.CopyTo($fileStream)

        $fileStream.Dispose()
        $stream.Dispose()

        Write-Verbose 'Workload package saved successfully.'
    }
}
