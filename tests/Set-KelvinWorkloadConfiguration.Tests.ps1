#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Set-KelvinWorkloadConfiguration' {

    Context 'Properties parameter set (default)' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{
                    configuration = [PSCustomObject]@{ key1 = 'updated' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Calls the correct configurations/update endpoint with POST' {
            Set-KelvinWorkloadConfiguration -Name 'my-workload' -Configuration @{ key1 = 'value1' }

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/my-workload/configurations/update' -and $Method -eq 'Post'
            }
        }

        It 'Wraps the Configuration in a body with the configuration key' {
            Set-KelvinWorkloadConfiguration -Name 'my-workload' -Configuration @{ key1 = 'value1' }

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.configuration.key1 -eq 'value1'
            }
        }

        It 'Returns the updated configuration' {
            $result = Set-KelvinWorkloadConfiguration -Name 'my-workload' -Configuration @{ key1 = 'value1' }
            $result.key1 | Should -Be 'updated'
        }
    }

    Context 'Body parameter set (fallback)' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{
                    configuration = [PSCustomObject]@{ raw = 'data' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Passes the Body hashtable directly to the API' {
            $rawBody = @{ configuration = @{ raw = 'data' } }
            Set-KelvinWorkloadConfiguration -Name 'my-workload' -Body $rawBody

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.configuration.raw -eq 'data'
            }
        }
    }

    Context 'ShouldProcess' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not call the API when -WhatIf is specified' {
            Set-KelvinWorkloadConfiguration -Name 'my-workload' -Configuration @{ k = 'v' } -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }

    Context 'Error handling' {

        BeforeAll {
            Mock Invoke-KelvinApi { throw 'API error' } -ModuleName PoshKelvin
        }

        It 'Writes an error when the API call fails' {
            $errVar = $null
            Set-KelvinWorkloadConfiguration -Name 'bad-wl' -Configuration @{ k = 'v' } -ErrorVariable errVar -ErrorAction SilentlyContinue
            $errVar | Should -Not -BeNullOrEmpty
        }
    }
}
