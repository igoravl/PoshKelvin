#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Install-KelvinWorkload' {

    Context 'Successful apply (single workload)' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Calls the apply endpoint with POST' {
            Install-KelvinWorkload -Name 'my-workload'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/apply' -and $Method -eq 'Post'
            }
        }

        It 'Sends the workload name in the body' {
            Install-KelvinWorkload -Name 'my-workload'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.workload_names -contains 'my-workload'
            }
        }

        It 'Does not produce output on success' {
            $result = Install-KelvinWorkload -Name 'my-workload'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Multiple workloads' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Sends all workload names in a single API call' {
            Install-KelvinWorkload -Name 'wl-a', 'wl-b'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.workload_names.Count -eq 2 -and
                $Body.workload_names -contains 'wl-a' -and
                $Body.workload_names -contains 'wl-b'
            }
        }
    }

    Context 'ShouldProcess' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not call the API when -WhatIf is specified' {
            Install-KelvinWorkload -Name 'my-workload' -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }

    Context 'Error handling' {

        BeforeAll {
            Mock Invoke-KelvinApi { throw 'API error' } -ModuleName PoshKelvin
        }

        It 'Writes an error when the API call fails' {
            $errVar = $null
            Install-KelvinWorkload -Name 'bad-workload' -ErrorVariable errVar -ErrorAction SilentlyContinue
            $errVar | Should -Not -BeNullOrEmpty
        }
    }
}
