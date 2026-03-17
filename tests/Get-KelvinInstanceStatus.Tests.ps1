#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinInstanceStatus' {

    Context 'Status call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ state = 'healthy'; version = '4.0.0' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the instance/status/get endpoint with GET' {
            Get-KelvinInstanceStatus

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'instance/status/get' -and $Method -eq 'Get'
            }
        }

        It 'Returns the status object' {
            $result = Get-KelvinInstanceStatus
            $result.state | Should -Be 'healthy'
        }

        It 'Returns objects typed as Kelvin.InstanceStatus' {
            Get-KelvinInstanceStatus
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.InstanceStatus'
            }
        }

        It 'Accepts no parameters' {
            { Get-KelvinInstanceStatus } | Should -Not -Throw
        }
    }
}
