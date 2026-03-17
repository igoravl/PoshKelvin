#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinParameterResource' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'res-a' }
                [PSCustomObject]@{ name = 'res-b' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the parameters/resources/list endpoint with GET' {
            Get-KelvinParameterResource

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'parameters/resources/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinParameterResource
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.ParameterResource' {
            Get-KelvinParameterResource
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.ParameterResource'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinParameterResource -Search 'my-res'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['search'] -contains 'my-res'
            }
        }
    }
}
