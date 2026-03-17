#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinRecommendationType' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'type-a' }
                [PSCustomObject]@{ name = 'type-b' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the recommendations/types/list endpoint with GET' {
            Get-KelvinRecommendationType

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'recommendations/types/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinRecommendationType
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.RecommendationType' {
            Get-KelvinRecommendationType
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.RecommendationType'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'type-a'; description = 'Type A detail' }
                }
                else {
                    [PSCustomObject]@{ name = 'type-a' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each recommendation type by name' {
            Get-KelvinRecommendationType -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'recommendations/types/type-a/get'
            }
        }
    }
}
