#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinWorkload' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{
                    name   = 'wl-1'
                    status = [PSCustomObject]@{ state = 'running' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Calls the workloads/list endpoint with GET' {
            Get-KelvinWorkload

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns objects typed as Kelvin.Workload' {
            Get-KelvinWorkload
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.Workload'
            }
        }

        It 'Adds a state NoteProperty from status.state' {
            $result = Get-KelvinWorkload
            $result[0].state | Should -Be 'running'
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinWorkload -Search 'myapp'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('search')
            }
        }

        It 'Forwards -ClusterName to the API query parameters' {
            Get-KelvinWorkload -ClusterName 'my-cluster'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('cluster_name')
            }
        }

        It 'Forwards -DownloadStatus to the API query parameters' {
            Get-KelvinWorkload -DownloadStatus ready

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('download_status')
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{
                        name   = 'wl-1'
                        status = [PSCustomObject]@{ state = 'running' }
                    }
                }
                else {
                    [PSCustomObject]@{
                        name   = 'wl-1'
                        status = [PSCustomObject]@{ state = 'running' }
                    }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each listed workload' {
            Get-KelvinWorkload -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/wl-1/get'
            }
        }
    }

    Context 'Pipeline input' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{
                    name   = 'pipe-wl'
                    status = [PSCustomObject]@{ state = 'ready' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Accepts ClusterName from the pipeline via property name' {
            [PSCustomObject]@{ cluster_name = 'piped-cluster' } | Get-KelvinWorkload

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('cluster_name')
            }
        }
    }
}
