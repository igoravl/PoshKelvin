#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinApp' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'app-1' }
                [PSCustomObject]@{ name = 'app-2' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the appregistry/list endpoint with GET' {
            Get-KelvinApp

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'appregistry/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinApp
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.App' {
            Get-KelvinApp
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.App'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinApp -Search 'my-app'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['search'] -contains 'my-app'
            }
        }

        It 'Forwards -Name to the API query parameters' {
            Get-KelvinApp -Name 'my-app'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['name'] -contains 'my-app'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'app-1'; version = '1.0' }
                }
                else {
                    [PSCustomObject]@{ name = 'app-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each listed app' {
            Get-KelvinApp -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'appregistry/app-1/get'
            }
        }
    }
}
