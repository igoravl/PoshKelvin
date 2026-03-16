$module = Get-ChildItem "output/*.psd1" -Recurse | Sort-Object LastWriteTime | Select-Object -Last 1

$dir = Split-Path $module.FullName -Parent

Copy-Item "$dir/*" $PSScriptRoot -Force

Get-Module -Name PoshKelvin | Remove-Module
Import-Module "$PSScriptRoot/PoshKelvin.psd1" -Force

Convert-Breakpoint -ModuleOnly

Write-Host "Module loaded: $($module.FullName)"