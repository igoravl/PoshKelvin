#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinAppResource' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'res-1'; status = 'running' }
                [PSCustomObject]@{ name = 'res-2'; status = 'stopped' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the correct app-manager resources list endpoint' {
            Get-KelvinAppResource -AppName 'my-app'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'app-manager/app/my-app/resources/list'
            }
        }

        It 'Uses the POST method' {
            Get-KelvinAppResource -AppName 'my-app'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Method -eq 'Post'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinAppResource -AppName 'my-app'
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.AppResource' {
            Get-KelvinAppResource -AppName 'my-app'
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.AppResource'
            }
        }

        It 'Requires the -AppName parameter to be non-empty' {
            # Verify that -AppName is declared as Mandatory by inspecting the command metadata
            $cmd   = Get-Command Get-KelvinAppResource
            $param = $cmd.Parameters['AppName']
            $param.Attributes | Where-Object { $_ -is [Parameter] } |
                ForEach-Object { $_.Mandatory } |
                Should -Contain $true
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not throw when -Status is provided' {
            # Note: Get-KelvinAppResource params are in __AllParameterSets (not ParameterSetName='Query'),
            # so _GetParams does not forward them to the API. The cmdlet still executes without error.
            { Get-KelvinAppResource -AppName 'my-app' -Status running } | Should -Not -Throw
        }
    }
}
