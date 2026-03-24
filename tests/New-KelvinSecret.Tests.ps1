#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'New-KelvinSecret' {

    Context 'Successful creation' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ name = 'my-secret' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the secrets/create endpoint with POST' {
            New-KelvinSecret -Name 'my-secret' -Value 'secret-value'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'secrets/create' -and $Method -eq 'Post'
            }
        }

        It 'Sends name and value in the body' {
            New-KelvinSecret -Name 'my-secret' -Value 'secret-value'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Body.name -eq 'my-secret' -and $Body.value -eq 'secret-value'
            }
        }

        It 'Returns the created secret object' {
            $result = New-KelvinSecret -Name 'my-secret' -Value 'secret-value'
            $result.name | Should -Be 'my-secret'
        }

        It 'Requests Kelvin.Secret type name' {
            New-KelvinSecret -Name 'my-secret' -Value 'secret-value'

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.Secret'
            }
        }
    }

    Context 'ShouldProcess' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not call the API when -WhatIf is specified' {
            New-KelvinSecret -Name 'my-secret' -Value 'secret-value' -WhatIf
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0
        }
    }

    Context 'Error handling' {

        BeforeAll {
            Mock Invoke-KelvinApi { throw 'API error' } -ModuleName PoshKelvin
        }

        It 'Writes an error when the API call fails' {
            $errVar = $null
            New-KelvinSecret -Name 'bad-secret' -Value 'value' -ErrorVariable errVar -ErrorAction SilentlyContinue
            $errVar | Should -Not -BeNullOrEmpty
        }
    }
}
