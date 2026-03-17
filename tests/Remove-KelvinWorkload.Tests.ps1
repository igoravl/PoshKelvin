#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Remove-KelvinWorkload' {

    Context 'Successful removal (single workload)' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Calls the correct undeploy endpoint with POST' {
            Remove-KelvinWorkload -Name 'my-workload' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/my-workload/undeploy' -and $Method -eq 'Post'
            }
        }

        It 'Does not produce output on success' {
            $result = Remove-KelvinWorkload -Name 'my-workload' -Force
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Multiple workloads' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Calls the undeploy endpoint once per workload name' {
            Remove-KelvinWorkload -Name 'wl-a', 'wl-b' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 2 -Exactly
        }

        It 'Uses the correct path for each workload name' {
            Remove-KelvinWorkload -Name 'wl-a', 'wl-b' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/wl-a/undeploy'
            }
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/wl-b/undeploy'
            }
        }
    }

    Context '-Staged parameter' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Staged $true to the API query parameters' {
            Remove-KelvinWorkload -Name 'my-workload' -Staged $true -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('staged')
            }
        }

        It 'Does not send -Staged when not specified' {
            Remove-KelvinWorkload -Name 'my-workload' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                -not $Parameters.ContainsKey('staged')
            }
        }
    }

    Context 'ShouldProcess / Confirmation' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not call the API when -WhatIf is specified' {
            Remove-KelvinWorkload -Name 'my-workload' -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }

    Context 'Error handling' {

        BeforeAll {
            Mock Invoke-KelvinApi { throw 'API error' } -ModuleName PoshKelvin
        }

        It 'Writes an error when the API call fails' {
            $errVar = $null
            Remove-KelvinWorkload -Name 'bad-workload' -Force -ErrorVariable errVar -ErrorAction SilentlyContinue
            $errVar | Should -Not -BeNullOrEmpty
        }
    }
}
