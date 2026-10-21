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

        It 'Does not call the API when -Force is combined with -WhatIf' {
            Remove-KelvinSecret -Name 'my-secret' -Force -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }

    Context 'Pipeline input' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Accepts secret objects returned by Get-KelvinSecret' {
            @(
                [PSCustomObject]@{ PSTypeName = 'Kelvin.Secret'; name = 'first-secret' }
                [PSCustomObject]@{ PSTypeName = 'Kelvin.Secret'; name = 'second-secret' }
            ) | Remove-KelvinSecret -Force

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 2 -Exactly
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
                $Path -eq 'secrets/second-secret/delete'
            }
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

    Context 'HTTP failure through Invoke-KelvinApi' {

        BeforeAll {
            Mock Invoke-RestMethod {
                if ($Uri.AbsolutePath -like '*/bad-secret/delete') { throw 'HTTP 404 Not Found' }
            } -ModuleName PoshKelvin
        }

        It 'Reports the failure and continues with the remaining secrets' {
            $errVar = $null
            Remove-KelvinSecret -Name 'bad-secret', 'good-secret' -Force -ErrorVariable errVar -ErrorAction SilentlyContinue

            ($errVar | Out-String) | Should -BeLike "*Failed to delete secret 'bad-secret'*"
            Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
                $Uri.AbsolutePath -like '*/good-secret/delete'
            }
        }
    }
}
