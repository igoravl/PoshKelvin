#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinDataStreamSemanticType' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'temperature' }
                [PSCustomObject]@{ name = 'humidity' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the datastreams/semantic-types/list endpoint with GET' {
            Get-KelvinDataStreamSemanticType

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datastreams/semantic-types/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinDataStreamSemanticType
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.DataStreamSemanticType' {
            Get-KelvinDataStreamSemanticType
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.DataStreamSemanticType'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'temperature'; description = 'Thermal measurement' }
                }
                else {
                    [PSCustomObject]@{ name = 'temperature' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each semantic type' {
            Get-KelvinDataStreamSemanticType -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datastreams/semantic-types/temperature/get'
            }
        }
    }
}
