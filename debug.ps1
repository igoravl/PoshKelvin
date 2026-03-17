$module = Get-ChildItem "output/*.psd1" -Recurse | Sort-Object LastWriteTime | Select-Object -Last 1

Get-Module -Name PoshKelvin | Remove-Module
Import-Module $module.FullName -Force

Convert-Breakpoint -ModuleOnly

# Shorthand to re-map breakpoints mid-session after adding new ones.
function cb { Convert-Breakpoint -ModuleOnly }

Write-Host "Module loaded: $($module.FullName)"
Write-Host "Type 'cb' to re-map breakpoints. Type 'exit' to end the debug session."

# Keep the debug session alive as an interactive REPL.
# Without this, the session would terminate as soon as this script finishes.
$Host.EnterNestedPrompt()