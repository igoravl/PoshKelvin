#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinDataStream' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'stream-1' }
                [PSCustomObject]@{ name = 'stream-2' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the datastreams/list endpoint with GET' {
            Get-KelvinDataStream

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datastreams/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinDataStream
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.DataStream' {
            Get-KelvinDataStream
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.DataStream'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinDataStream -Search 'temp'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['search'] -contains 'temp'
            }
        }

        It 'Forwards -AssetName to the API query parameters' {
            Get-KelvinDataStream -AssetName 'my-asset'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('asset_name')
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'stream-1'; unit = 'celsius' }
                }
                else {
                    [PSCustomObject]@{ name = 'stream-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each listed data stream' {
            Get-KelvinDataStream -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datastreams/stream-1/get'
            }
        }
    }
}
