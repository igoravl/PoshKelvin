#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinInstanceSetting' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'max-threads'; value = '8' }
                [PSCustomObject]@{ name = 'log-level'; value = 'info' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the instance/settings/list endpoint with GET' {
            Get-KelvinInstanceSetting

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'instance/settings/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinInstanceSetting
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.InstanceSetting' {
            Get-KelvinInstanceSetting
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.InstanceSetting'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'max-threads'; description = 'Max concurrent threads' }
                }
                else {
                    [PSCustomObject]@{ name = 'max-threads' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each setting by name' {
            Get-KelvinInstanceSetting -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'instance/settings/max-threads/get'
            }
        }
    }
}
