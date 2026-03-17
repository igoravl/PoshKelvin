#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Stop-KelvinWorkload' {

    Context 'Successful stop (single workload)' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Calls the correct stop endpoint with GET' {
            Stop-KelvinWorkload -Name 'my-workload'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/my-workload/stop' -and $Method -eq 'Get'
            }
        }

        It 'Does not produce output on success' {
            $result = Stop-KelvinWorkload -Name 'my-workload'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Multiple workloads' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Calls the stop endpoint once per workload name' {
            Stop-KelvinWorkload -Name 'wl-a', 'wl-b'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 2 -Exactly
        }

        It 'Uses the correct path for each workload name' {
            Stop-KelvinWorkload -Name 'wl-a', 'wl-b'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/wl-a/stop'
            }
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/wl-b/stop'
            }
        }
    }

    Context 'Pipeline input' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Accepts Name from the pipeline via property name' {
            [PSCustomObject]@{ workload_name = 'piped-wl' } | Stop-KelvinWorkload

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/piped-wl/stop'
            }
        }
    }

    Context 'ShouldProcess' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not call the API when -WhatIf is specified' {
            Stop-KelvinWorkload -Name 'my-workload' -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }

    Context 'Error handling' {

        BeforeAll {
            Mock Invoke-KelvinApi { throw 'API error' } -ModuleName PoshKelvin
        }

        It 'Writes an error when the API call fails' {
            $errVar = $null
            Stop-KelvinWorkload -Name 'bad-workload' -ErrorVariable errVar -ErrorAction SilentlyContinue
            $errVar | Should -Not -BeNullOrEmpty
        }
    }
}
