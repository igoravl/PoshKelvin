#requires -Module InvokeBuild, ModuleBuilder -Version 7.0

param (
    [string[]] $Task,
    [string]   $FeedUrl = $env:FEED_URL,
    [string]   $ApiKey  = $env:API_KEY
)

Import-Module InvokeBuild

$buildArgs = @{}
if ($Task) { $buildArgs['Task'] = $Task }

Invoke-Build @buildArgs