#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinFile' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ id = 'file-1'; name = 'config.json' }
                [PSCustomObject]@{ id = 'file-2'; name = 'model.bin' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the filestorage/list endpoint with GET' {
            Get-KelvinFile

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'filestorage/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinFile
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.File' {
            Get-KelvinFile
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.File'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Forwards -Search to the API query parameters' {
            Get-KelvinFile -Search 'config'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters['search'] -contains 'config'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ id = 'file-1'; size = 1024 }
                }
                else {
                    [PSCustomObject]@{ id = 'file-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each file using its id' {
            Get-KelvinFile -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'filestorage/file-1/get'
            }
        }
    }
}
