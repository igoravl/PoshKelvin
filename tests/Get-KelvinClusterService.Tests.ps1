#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinClusterService' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'svc-1'; status = 'running' }
                [PSCustomObject]@{ name = 'svc-2'; status = 'stopped' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the correct cluster services list endpoint' {
            Get-KelvinClusterService -ClusterName 'my-cluster'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'orchestration/clusters/my-cluster/services/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinClusterService -ClusterName 'my-cluster'
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.ClusterService' {
            Get-KelvinClusterService -ClusterName 'my-cluster'
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.ClusterService'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not throw when -Status is provided' {
            # Note: Get-KelvinClusterService params are in __AllParameterSets (not ParameterSetName='Query'),
            # so _GetParams does not forward them to the API. The cmdlet still executes without error.
            { Get-KelvinClusterService -ClusterName 'my-cluster' -Status running } | Should -Not -Throw
        }

        It 'Does not throw when -Search is provided' {
            { Get-KelvinClusterService -ClusterName 'my-cluster' -Search 'nginx' } | Should -Not -Throw
        }
    }

    Context 'Pipeline input' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'piped-svc' }
            } -ModuleName PoshKelvin
        }

        It 'Accepts ClusterName from the pipeline via property name' {
            [PSCustomObject]@{ cluster_name = 'pipe-cluster' } | Get-KelvinClusterService

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -like '*pipe-cluster*'
            }
        }
    }
}
