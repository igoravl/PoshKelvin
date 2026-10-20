#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe '_GetPlaywrightInfo' {

    BeforeEach {
        $previousPath = $env:POSHKELVIN_PLAYWRIGHT_PATH
        $env:POSHKELVIN_PLAYWRIGHT_PATH = Join-Path $TestDrive ([guid]::NewGuid())
    }

    AfterEach {
        $env:POSHKELVIN_PLAYWRIGHT_PATH = $previousPath
    }

    It 'Honors the POSHKELVIN_PLAYWRIGHT_PATH environment variable' {
        $info = InModuleScope PoshKelvin { _GetPlaywrightInfo }

        $info.Root | Should -Be $env:POSHKELVIN_PLAYWRIGHT_PATH
        $info.AssemblyPath | Should -Be (Join-Path $env:POSHKELVIN_PLAYWRIGHT_PATH "$($info.Version)/Microsoft.Playwright.dll")
        $info.BrowsersPath | Should -Be (Join-Path $env:POSHKELVIN_PLAYWRIGHT_PATH 'browsers')
    }

    It 'Reports every missing prerequisite' {
        $info = InModuleScope PoshKelvin { _GetPlaywrightInfo }

        $info.IsInstalled | Should -BeFalse
        $info.Missing | Should -HaveCount 3
    }

    It 'Reports the prerequisites as installed when all files are present' {
        $info = InModuleScope PoshKelvin { _GetPlaywrightInfo }
        $node = if ($info.Platform -like 'win32*') { 'node.exe' } else { 'node' }
        New-Item -ItemType File -Force -Path $info.AssemblyPath | Out-Null
        New-Item -ItemType File -Force -Path (Join-Path $info.Root "$($info.Version)/.playwright/node/$($info.Platform)/$node") | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $info.BrowsersPath 'chromium-1234') | Out-Null

        $info = InModuleScope PoshKelvin { _GetPlaywrightInfo }

        $info.IsInstalled | Should -BeTrue
        $info.Missing | Should -BeNullOrEmpty
    }

    It 'Uses the same Playwright version as the setup script' {
        $info = InModuleScope PoshKelvin { _GetPlaywrightInfo }
        $script = Get-Command (Join-Path (Get-Module PoshKelvin).ModuleBase 'scripts/Install-KelvinInteractivePrerequisites.ps1')

        $script.Parameters['Version'] | Should -Not -BeNullOrEmpty
        $default = $script.ScriptBlock.Ast.ParamBlock.Parameters |
            Where-Object { $_.Name.VariablePath.UserPath -eq 'Version' } |
            ForEach-Object { $_.DefaultValue.Value }
        $default | Should -Be $info.Version
    }
}
