#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinRecommendation' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ id = 'rec-1'; status = 'pending' }
                [PSCustomObject]@{ id = 'rec-2'; status = 'accepted' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the recommendations/list endpoint with GET' {
            Get-KelvinRecommendation

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'recommendations/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinRecommendation
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.Recommendation' {
            Get-KelvinRecommendation
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.Recommendation'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Status to the API query parameters' {
            Get-KelvinRecommendation -Status pending

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['status'] -contains 'pending'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ id = 'rec-1'; details = 'Detailed recommendation' }
                }
                else {
                    [PSCustomObject]@{ id = 'rec-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call per recommendation using its id' {
            Get-KelvinRecommendation -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'recommendations/rec-1/get'
            }
        }
    }
}
