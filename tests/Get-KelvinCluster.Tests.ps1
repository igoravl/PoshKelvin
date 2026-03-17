#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinCluster' {

    Context 'List call (no filters)' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'cluster-a'; status = 'online' }
                [PSCustomObject]@{ name = 'cluster-b'; status = 'offline' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the clusters/list endpoint with GET' {
            Get-KelvinCluster

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'orchestration/clusters/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinCluster
            $result.Count | Should -Be 2
        }

        It 'Adds a cluster_name NoteProperty matching the name field' {
            $result = Get-KelvinCluster
            $result[0].cluster_name | Should -Be 'cluster-a'
            $result[1].cluster_name | Should -Be 'cluster-b'
        }

        It 'Returns objects typed as Kelvin.Cluster' {
            Get-KelvinCluster
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.Cluster'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Status to the API query parameters' {
            Get-KelvinCluster -Status online

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['status'] -contains 'online'
            }
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinCluster -Search 'prod'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['search'] -contains 'prod'
            }
        }

        It 'Forwards -Ready $true to the API query parameters' {
            Get-KelvinCluster -Ready $true

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('ready') -and $Parameters['ready'] -eq $true
            }
        }

        It 'Forwards -Ready $false to the API query parameters' {
            Get-KelvinCluster -Ready $false

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('ready') -and $Parameters['ready'] -eq $false
            }
        }

        It 'Does not forward -Ready when omitted' {
            Get-KelvinCluster

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                -not $Parameters.ContainsKey('ready')
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'cluster-detail'; description = 'Full detail' }
                }
                else {
                    [PSCustomObject]@{ name = 'cluster-a' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each listed cluster' {
            Get-KelvinCluster -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'orchestration/clusters/cluster-a/get'
            }
        }
    }
}
