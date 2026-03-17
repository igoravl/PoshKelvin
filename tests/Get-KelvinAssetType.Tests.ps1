#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinAssetType' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'sensor' }
                [PSCustomObject]@{ name = 'actuator' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the assets/types/list endpoint with GET' {
            Get-KelvinAssetType

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'assets/types/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items' {
            $result = Get-KelvinAssetType
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.AssetType' {
            Get-KelvinAssetType
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.AssetType'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinAssetType -Search 'temp'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['search'] -contains 'temp'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'sensor'; description = 'A sensor type' }
                }
                else {
                    [PSCustomObject]@{ name = 'sensor' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each listed asset type' {
            Get-KelvinAssetType -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'assets/types/sensor/get'
            }
        }
    }
}
