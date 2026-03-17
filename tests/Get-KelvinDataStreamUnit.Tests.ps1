#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinDataStreamUnit' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'celsius' }
                [PSCustomObject]@{ name = 'fahrenheit' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the datastreams/units/list endpoint with GET' {
            Get-KelvinDataStreamUnit

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datastreams/units/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinDataStreamUnit
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.DataStreamUnit' {
            Get-KelvinDataStreamUnit
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.DataStreamUnit'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'celsius'; symbol = '°C' }
                }
                else {
                    [PSCustomObject]@{ name = 'celsius' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each unit' {
            Get-KelvinDataStreamUnit -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datastreams/units/celsius/get'
            }
        }
    }
}
