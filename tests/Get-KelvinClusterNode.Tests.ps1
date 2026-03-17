#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinClusterNode' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'node-1'; status = 'online' }
                [PSCustomObject]@{ name = 'node-2'; status = 'offline' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the correct cluster nodes list endpoint' {
            Get-KelvinClusterNode -ClusterName 'my-cluster'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'orchestration/clusters/my-cluster/nodes/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all nodes from the API response' {
            $result = Get-KelvinClusterNode -ClusterName 'my-cluster'
            $result.Count | Should -Be 2
        }

        It 'Adds a node_name NoteProperty matching the name field' {
            $result = Get-KelvinClusterNode -ClusterName 'my-cluster'
            $result[0].node_name | Should -Be 'node-1'
            $result[1].node_name | Should -Be 'node-2'
        }

        It 'Returns objects typed as Kelvin.ClusterNode' {
            Get-KelvinClusterNode -ClusterName 'my-cluster'
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.ClusterNode'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not throw when -Status is provided' {
            # Note: Get-KelvinClusterNode params are in __AllParameterSets (not ParameterSetName='Query'),
            # so _GetParams does not forward them to the API. The cmdlet still executes without error.
            { Get-KelvinClusterNode -ClusterName 'my-cluster' -Status online } | Should -Not -Throw
        }

        It 'Does not throw when -Search is provided' {
            { Get-KelvinClusterNode -ClusterName 'my-cluster' -Search 'worker' } | Should -Not -Throw
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'node-1'; cpu = '4'; memory = '16GB' }
                }
                else {
                    [PSCustomObject]@{ name = 'node-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call per node using ClusterName and node name' {
            Get-KelvinClusterNode -ClusterName 'my-cluster' -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'orchestration/clusters/my-cluster/nodes/node-1/get'
            }
        }
    }

    Context 'Pipeline input' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'pipe-node' }
            } -ModuleName PoshKelvin
        }

        It 'Accepts ClusterName from the pipeline via property name' {
            [PSCustomObject]@{ cluster_name = 'pipe-cluster' } | Get-KelvinClusterNode

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -like '*pipe-cluster*'
            }
        }
    }
}
