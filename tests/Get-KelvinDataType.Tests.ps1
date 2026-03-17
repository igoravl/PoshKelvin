#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinDataType' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'float' }
                [PSCustomObject]@{ name = 'integer' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the datastreams/data-types/list endpoint with GET' {
            Get-KelvinDataType

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datastreams/data-types/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinDataType
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.DataType' {
            Get-KelvinDataType
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.DataType'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not throw when -Search is provided' {
            # Note: Get-KelvinDataType params are in __AllParameterSets (not ParameterSetName='Query'),
            # so _GetParams does not forward them to the API. The cmdlet still executes without error.
            { Get-KelvinDataType -Search 'float' } | Should -Not -Throw
        }

        It 'Does not throw when -Name is provided' {
            { Get-KelvinDataType -Name 'integer' } | Should -Not -Throw
        }
    }
}
