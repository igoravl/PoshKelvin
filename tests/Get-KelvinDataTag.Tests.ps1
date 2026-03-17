#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinDataTag' {

    Context 'Default (data tag instances) list call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ id = 'dt-1'; name = 'tag-instance-1' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the datatags/list endpoint with GET' {
            # Passing -Search forces the Query parameter set, avoiding parameter set ambiguity
            Get-KelvinDataTag -Search 'any'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datatags/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns objects typed as Kelvin.DataTag' {
            Get-KelvinDataTag -Search 'any'
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.DataTag'
            }
        }
    }

    Context '-Tags switch (tag definitions)' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'my-tag-def' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the datatags/tags/list endpoint with GET when -Tags is specified' {
            Get-KelvinDataTag -Tags

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datatags/tags/list' -and $Method -eq 'Get'
            }
        }
    }

    Context '-Detailed switch — data tag instances' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ id = 'dt-1'; detail = 'more info' }
                }
                else {
                    [PSCustomObject]@{ id = 'dt-1'; name = 'tag-instance-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail call using the id property' {
            # -Search forces the Query parameter set
            Get-KelvinDataTag -Search 'any' -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datatags/dt-1/get'
            }
        }
    }

    Context '-Detailed switch — tag definitions' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ name = 'my-tag-def'; description = 'A tag definition' }
                }
                else {
                    [PSCustomObject]@{ name = 'my-tag-def' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail call using the name property for tag definitions' {
            Get-KelvinDataTag -Tags -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'datatags/tags/my-tag-def/get'
            }
        }
    }
}
