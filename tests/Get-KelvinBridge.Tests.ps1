#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinBridge' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'bridge-1'; running = $true }
                [PSCustomObject]@{ name = 'bridge-2'; running = $false }
            } -ModuleName PoshKelvin
        }

        It 'Calls the bridges/list endpoint with GET' {
            Get-KelvinBridge

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'bridges/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinBridge
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.Bridge' {
            Get-KelvinBridge
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.Bridge'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinBridge -Search 'prod'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['search'] -contains 'prod'
            }
        }

        It 'Forwards -Running $true to the API query parameters' {
            Get-KelvinBridge -Running $true

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('running') -and $Parameters['running'] -eq $true
            }
        }

        It 'Forwards -Running $false to the API query parameters' {
            Get-KelvinBridge -Running $false

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('running') -and $Parameters['running'] -eq $false
            }
        }

        It 'Does not forward -Running when omitted' {
            Get-KelvinBridge

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                -not $Parameters.ContainsKey('running')
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'bridge-1'; type = 'mqtt' }
                }
                else {
                    [PSCustomObject]@{ name = 'bridge-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each listed bridge' {
            Get-KelvinBridge -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'bridges/bridge-1/get'
            }
        }
    }
}
