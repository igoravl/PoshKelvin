#requires -Module InvokeBuild, ModuleBuilder -Version 7.0

param (
    [string]$FeedUrl = $env:FEED_URL,
    [string]$ApiKey = $env:API_KEY
)

Import-Module InvokeBuild

Invoke-Build