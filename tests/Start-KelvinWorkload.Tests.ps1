#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Start-KelvinWorkload' {

    Context 'Successful start (single workload)' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Calls the correct start endpoint with GET' {
            Start-KelvinWorkload -Name 'my-workload'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/my-workload/start' -and $Method -eq 'Get'
            }
        }

        It 'Does not produce output on success' {
            $result = Start-KelvinWorkload -Name 'my-workload'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Multiple workloads' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Calls the start endpoint once per workload name' {
            Start-KelvinWorkload -Name 'wl-a', 'wl-b'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 2 -Exactly
        }

        It 'Uses the correct path for each workload name' {
            Start-KelvinWorkload -Name 'wl-a', 'wl-b'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/wl-a/start'
            }
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/wl-b/start'
            }
        }
    }

    Context 'Pipeline input' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Accepts Name from the pipeline via property name' {
            [PSCustomObject]@{ workload_name = 'piped-wl' } | Start-KelvinWorkload

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/piped-wl/start'
            }
        }
    }

    Context 'ShouldProcess' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not call the API when -WhatIf is specified' {
            Start-KelvinWorkload -Name 'my-workload' -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }

    Context 'Error handling' {

        BeforeAll {
            Mock Invoke-KelvinApi { throw 'API error' } -ModuleName PoshKelvin
        }

        It 'Writes an error when the API call fails' {
            $errVar = $null
            Start-KelvinWorkload -Name 'bad-workload' -ErrorVariable errVar -ErrorAction SilentlyContinue
            $errVar | Should -Not -BeNullOrEmpty
        }
    }
}
