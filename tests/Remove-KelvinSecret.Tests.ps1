#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Remove-KelvinSecret' {

    Context 'Successful removal (single secret)' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Calls the correct delete endpoint with POST' {
            Remove-KelvinSecret -Name 'my-secret' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'secrets/my-secret/delete' -and $Method -eq 'Post'
            }
        }

        It 'Does not produce output on success' {
            $result = Remove-KelvinSecret -Name 'my-secret' -Force
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Multiple secrets' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Calls the delete endpoint once per secret name' {
            Remove-KelvinSecret -Name 'secret-a', 'secret-b' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 2 -Exactly
        }

        It 'Uses the correct path for each secret name' {
            Remove-KelvinSecret -Name 'secret-a', 'secret-b' -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'secrets/secret-a/delete'
            }
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'secrets/secret-b/delete'
            }
        }
    }

    Context 'ShouldProcess / Confirmation' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not call the API when -WhatIf is specified' {
            Remove-KelvinSecret -Name 'my-secret' -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }

    Context 'Error handling' {

        BeforeAll {
            Mock Invoke-KelvinApi { throw 'API error' } -ModuleName PoshKelvin
        }

        It 'Writes an error when the API call fails' {
            $errVar = $null
            Remove-KelvinSecret -Name 'bad-secret' -Force -ErrorVariable errVar -ErrorAction SilentlyContinue
            $errVar | Should -Not -BeNullOrEmpty
        }
    }
}
