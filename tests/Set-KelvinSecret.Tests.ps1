#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Set-KelvinSecret' {

    Context 'Successful update' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -eq 'secrets/create') {
                    [PSCustomObject]@{ name = 'my-secret' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Calls the delete endpoint first, then the create endpoint' {
            Set-KelvinSecret -Name 'my-secret' -Value 'new-value' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'secrets/my-secret/delete' -and $Method -eq 'Post'
            }
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'secrets/create' -and $Method -eq 'Post'
            }
        }

        It 'Sends name and value in the create body' {
            Set-KelvinSecret -Name 'my-secret' -Value 'new-value' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.name -eq 'my-secret' -and $Body.value -eq 'new-value'
            }
        }

        It 'Returns the created secret object' {
            $result = Set-KelvinSecret -Name 'my-secret' -Value 'new-value' -Force
            $result.name | Should -Be 'my-secret'
        }

        It 'Requests Kelvin.Secret type name on create' {
            Set-KelvinSecret -Name 'my-secret' -Value 'new-value' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.Secret'
            }
        }
    }

    Context 'Delete failure stops create' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -match '/delete$') { throw 'delete failed' }
                [PSCustomObject]@{ name = 'my-secret' }
            } -ModuleName PoshKelvin
        }

        It 'Writes an error and does not call create when delete fails' {
            $errVar = $null
            Set-KelvinSecret -Name 'my-secret' -Value 'val' -Force -ErrorVariable errVar -ErrorAction SilentlyContinue

            $errVar | Should -Not -BeNullOrEmpty

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'secrets/create'
            } -Times 0
        }
    }

    Context 'Create failure' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -match '/delete$') { return }
                throw 'create failed'
            } -ModuleName PoshKelvin
        }

        It 'Writes an error when create fails after successful delete' {
            $errVar = $null
            Set-KelvinSecret -Name 'my-secret' -Value 'val' -Force -ErrorVariable errVar -ErrorAction SilentlyContinue
            $errVar | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ShouldProcess / Confirmation' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not call the API when -WhatIf is specified' {
            Set-KelvinSecret -Name 'my-secret' -Value 'val' -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }
}
