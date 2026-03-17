#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinWorkloadLog' {

    Context 'Basic retrieval' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{
                    logs = [PSCustomObject]@{
                        'main-container' = @('line1', 'line2')
                    }
                }
            } -ModuleName PoshKelvin
        }

        It 'Calls the correct logs/get endpoint with GET' {
            Get-KelvinWorkloadLog -Name 'my-workload'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/my-workload/logs/get' -and $Method -eq 'Get'
            }
        }

        It 'Returns the logs object' {
            $result = Get-KelvinWorkloadLog -Name 'my-workload'
            $result.'main-container' | Should -Contain 'line1'
        }
    }

    Context '-TailLines parameter' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ logs = [PSCustomObject]@{ c = @('line') } }
            } -ModuleName PoshKelvin
        }

        It 'Forwards -TailLines to the API query parameters' {
            Get-KelvinWorkloadLog -Name 'my-workload' -TailLines 50

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.tail_lines -eq 50
            }
        }

        It 'Does not send tail_lines when not specified' {
            Get-KelvinWorkloadLog -Name 'my-workload'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                -not $Parameters.ContainsKey('tail_lines')
            }
        }
    }

    Context '-SinceTime parameter' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ logs = [PSCustomObject]@{ c = @('line') } }
            } -ModuleName PoshKelvin
        }

        It 'Forwards -SinceTime as an RFC 3339 UTC string' {
            $testDate = [datetime]::new(2026, 3, 17, 12, 0, 0, [System.DateTimeKind]::Utc)
            Get-KelvinWorkloadLog -Name 'my-workload' -SinceTime $testDate

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('since_time') -and
                $Parameters.since_time -match '2026-03-17T12:00:00'
            }
        }
    }

    Context 'Pipeline input' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ logs = [PSCustomObject]@{ c = @('line') } }
            } -ModuleName PoshKelvin
        }

        It 'Accepts Name from the pipeline via property name' {
            [PSCustomObject]@{ workload_name = 'piped-wl' } | Get-KelvinWorkloadLog

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/piped-wl/logs/get'
            }
        }
    }
}
