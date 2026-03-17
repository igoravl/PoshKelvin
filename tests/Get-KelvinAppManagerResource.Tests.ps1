#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinAppManagerResource' {

    Context 'Get call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ krn = 'krn:my-resource'; type = 'datastream' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the correct app-manager/resource endpoint with GET' {
            Get-KelvinAppManagerResource -ResourceKrn 'krn:my-resource'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'app-manager/resource/krn:my-resource/get' -and $Method -eq 'Get'
            }
        }

        It 'Returns the resource object' {
            $result = Get-KelvinAppManagerResource -ResourceKrn 'krn:my-resource'
            $result.krn | Should -Be 'krn:my-resource'
        }

        It 'Returns objects typed as Kelvin.AppManagerResource' {
            Get-KelvinAppManagerResource -ResourceKrn 'krn:my-resource'
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.AppManagerResource'
            }
        }

        It 'Requires the -ResourceKrn parameter to be non-empty' {
            # Verify that -ResourceKrn is declared as Mandatory by inspecting the command metadata
            $cmd   = Get-Command Get-KelvinAppManagerResource
            $param = $cmd.Parameters['ResourceKrn']
            $param.Attributes | Where-Object { $_ -is [Parameter] } |
                ForEach-Object { $_.Mandatory } |
                Should -Contain $true
        }
    }
}
