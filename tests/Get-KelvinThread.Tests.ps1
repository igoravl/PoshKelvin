#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinThread' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ id = 'thr-1'; title = 'Thread One' }
                [PSCustomObject]@{ id = 'thr-2'; title = 'Thread Two' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the threads/list endpoint with GET' {
            Get-KelvinThread

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'threads/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinThread
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.Thread' {
            Get-KelvinThread
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.Thread'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ id = 'thr-1'; messages = @() }
                }
                else {
                    [PSCustomObject]@{ id = 'thr-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each thread using its id' {
            Get-KelvinThread -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'threads/thr-1/get'
            }
        }
    }
}
