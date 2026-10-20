function _ConfirmPrerequisiteInstall {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # The calling cmdlet, used to prompt the user.
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet] $Cmdlet,

        # The installation folder shown to the user.
        [Parameter(Mandatory)]
        [string] $Path
    )

    $nonInteractive = -not [Environment]::UserInteractive -or
        ([Environment]::GetCommandLineArgs() | Where-Object { $_ -match '^-noni' })
    if ($nonInteractive) {
        Write-Verbose 'Non-interactive session. Not offering to install the prerequisites.'
        return $false
    }

    try {
        return $Cmdlet.ShouldContinue(
            "Download and install Playwright and Chromium (about 380 MB download, 550 MB on disk) into '$Path' now?",
            'Interactive authentication prerequisites are missing')
    }
    catch {
        Write-Verbose "Unable to prompt for confirmation: $($_.Exception.Message)"
        return $false
    }
}
