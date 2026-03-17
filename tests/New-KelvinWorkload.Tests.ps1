#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'New-KelvinWorkload' {

    Context 'Properties parameter set (default)' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{
                    name         = 'my-workload'
                    app_name     = 'my-app'
                    cluster_name = 'my-cluster'
                }
            } -ModuleName PoshKelvin
        }

        It 'Calls the deploy endpoint with POST' {
            New-KelvinWorkload -AppName 'my-app'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'workloads/deploy' -and $Method -eq 'Post'
            }
        }

        It 'Sends app_name in the body' {
            New-KelvinWorkload -AppName 'my-app'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.app_name -eq 'my-app'
            }
        }

        It 'Includes optional parameters when specified' {
            New-KelvinWorkload -AppName 'my-app' -Name 'wl-1' -ClusterName 'my-cluster' -AppVersion '1.0.0'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.app_name -eq 'my-app' -and
                $Body.name -eq 'wl-1' -and
                $Body.cluster_name -eq 'my-cluster' -and
                $Body.app_version -eq '1.0.0'
            }
        }

        It 'Sets instantly_apply to true when -InstantlyApply is specified' {
            New-KelvinWorkload -AppName 'my-app' -InstantlyApply

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.instantly_apply -eq $true
            }
        }

        It 'Sets staged to true when -Staged is specified' {
            New-KelvinWorkload -AppName 'my-app' -Staged

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.staged -eq $true
            }
        }

        It 'Does not include unspecified optional parameters' {
            New-KelvinWorkload -AppName 'my-app'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                -not $Body.ContainsKey('name') -and
                -not $Body.ContainsKey('cluster_name') -and
                -not $Body.ContainsKey('staged') -and
                -not $Body.ContainsKey('instantly_apply')
            }
        }

        It 'Returns the created workload object' {
            $result = New-KelvinWorkload -AppName 'my-app'
            $result.app_name | Should -Be 'my-app'
        }

        It 'Requests Kelvin.Workload type name' {
            New-KelvinWorkload -AppName 'my-app'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.Workload'
            }
        }
    }

    Context 'Body parameter set (fallback)' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'raw-wl'; app_name = 'raw-app' }
            } -ModuleName PoshKelvin
        }

        It 'Passes the Body hashtable directly to the API' {
            $rawBody = @{ app_name = 'raw-app'; payload = @{ inputs = @{} } }
            New-KelvinWorkload -Body $rawBody

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.app_name -eq 'raw-app' -and $Body.payload.ContainsKey('inputs')
            }
        }
    }

    Context 'ShouldProcess' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not call the API when -WhatIf is specified' {
            New-KelvinWorkload -AppName 'my-app' -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }

    Context 'Error handling' {

        BeforeAll {
            Mock Invoke-KelvinApi { throw 'API error' } -ModuleName PoshKelvin
        }

        It 'Writes an error when the API call fails' {
            $errVar = $null
            New-KelvinWorkload -AppName 'bad-app' -ErrorVariable errVar -ErrorAction SilentlyContinue
            $errVar | Should -Not -BeNullOrEmpty
        }
    }
}
