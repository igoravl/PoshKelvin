#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinWorkloadConfiguration' {

    Context 'Successful retrieval' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{
                    configuration = [PSCustomObject]@{ key1 = 'value1'; key2 = 42 }
                }
            } -ModuleName PoshKelvin
        }

        It 'Calls the correct configurations/get endpoint with GET' {
            Get-KelvinWorkloadConfiguration -Name 'my-workload'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/my-workload/configurations/get' -and $Method -eq 'Get'
            }
        }

        It 'Returns the configuration object' {
            $result = Get-KelvinWorkloadConfiguration -Name 'my-workload'
            $result.key1 | Should -Be 'value1'
            $result.key2 | Should -Be 42
        }
    }

    Context 'Pipeline input' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{
                    configuration = [PSCustomObject]@{ key1 = 'value1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Accepts Name from the pipeline via property name' {
            [PSCustomObject]@{ workload_name = 'piped-wl' } | Get-KelvinWorkloadConfiguration

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/piped-wl/configurations/get'
            }
        }
    }
}
