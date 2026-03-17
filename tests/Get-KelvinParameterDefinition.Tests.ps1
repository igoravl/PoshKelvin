#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinParameterDefinition' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'param-a'; type = 'string' }
                [PSCustomObject]@{ name = 'param-b'; type = 'integer' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the parameters/definitions/list endpoint with GET' {
            Get-KelvinParameterDefinition

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'parameters/definitions/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinParameterDefinition
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.ParameterDefinition' {
            Get-KelvinParameterDefinition
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.ParameterDefinition'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Type to the API query parameters' {
            Get-KelvinParameterDefinition -Type string

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['type'] -contains 'string'
            }
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinParameterDefinition -Search 'threshold'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['search'] -contains 'threshold'
            }
        }
    }
}
