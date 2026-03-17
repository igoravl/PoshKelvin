#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinAsset' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'asset-1'; status = 'online' }
                [PSCustomObject]@{ name = 'asset-2'; status = 'offline' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the assets/list endpoint with GET' {
            Get-KelvinAsset

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'assets/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinAsset
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.Asset' {
            Get-KelvinAsset
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.Asset'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Status to the API query parameters' {
            Get-KelvinAsset -Status online

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['status'] -contains 'online'
            }
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinAsset -Search 'sensor'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['search'] -contains 'sensor'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'asset-1'; type = 'sensor' }
                }
                else {
                    [PSCustomObject]@{ name = 'asset-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each listed asset' {
            Get-KelvinAsset -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'assets/asset-1/get'
            }
        }
    }
}
