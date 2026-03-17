#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe '_GetPaginatedData' {

    Context 'Non-paginated response' {

        BeforeAll {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ id = 'item-1'; name = 'Item One' }
            } -ModuleName PoshKelvin
        }

        It 'Returns the raw response when there is no pagination property' {
            $result = InModuleScope PoshKelvin {
                _GetPaginatedData -Uri 'https://kelvin.example.com/api/v4/test' `
                    -Method 'GET' -Headers @{} -ContentType 'application/json'
            }
            $result.id   | Should -Be 'item-1'
            $result.name | Should -Be 'Item One'
        }
    }

    Context 'Paginated response — single page' {

        BeforeAll {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    pagination = [PSCustomObject]@{ next_page = $null; previous_page = $null }
                    data       = @(
                        [PSCustomObject]@{ name = 'item-a' }
                        [PSCustomObject]@{ name = 'item-b' }
                    )
                }
            } -ModuleName PoshKelvin
        }

        It 'Returns all items from the data array' {
            $results = InModuleScope PoshKelvin {
                _GetPaginatedData -Uri 'https://kelvin.example.com/api/v4/test' `
                    -Method 'GET' -Headers @{} -ContentType 'application/json'
            }
            $results.Count | Should -Be 2
            $results[0].name | Should -Be 'item-a'
            $results[1].name | Should -Be 'item-b'
        }

        It 'Attaches a TypeName to every returned item when -TypeName is specified' {
            $results = InModuleScope PoshKelvin {
                _GetPaginatedData -Uri 'https://kelvin.example.com/api/v4/test' `
                    -Method 'GET' -Headers @{} -ContentType 'application/json' `
                    -TypeName 'Kelvin.TestItem'
            }
            foreach ($item in $results) {
                $item.PSObject.TypeNames | Should -Contain 'Kelvin.TestItem'
            }
        }
    }

    Context 'Paginated response — multiple pages' {

        BeforeAll {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return [PSCustomObject]@{
                        pagination = [PSCustomObject]@{ next_page = 'page2token'; previous_page = $null }
                        data       = @([PSCustomObject]@{ name = 'item-page1' })
                    }
                }
                else {
                    return [PSCustomObject]@{
                        pagination = [PSCustomObject]@{ next_page = $null; previous_page = 'page1token' }
                        data       = @([PSCustomObject]@{ name = 'item-page2' })
                    }
                }
            } -ModuleName PoshKelvin
        }

        It 'Follows next_page and calls Invoke-RestMethod once per page' {
            $results = InModuleScope PoshKelvin {
                _GetPaginatedData -Uri 'https://kelvin.example.com/api/v4/test' `
                    -Method 'GET' -Headers @{} -ContentType 'application/json'
            }
            $results.Count | Should -Be 2
            $results.name  | Should -Contain 'item-page1'
            $results.name  | Should -Contain 'item-page2'
            Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 2 -Exactly
        }
    }

    Context 'Error handling' {

        It 'Writes an error when Invoke-RestMethod throws a WebException' {
            Mock Invoke-RestMethod {
                $ex = [System.Net.WebException]::new('Simulated HTTP failure')
                throw $ex
            } -ModuleName PoshKelvin

            InModuleScope PoshKelvin {
                $errRec = $null
                _GetPaginatedData -Uri 'https://kelvin.example.com/api/v4/test' `
                    -Method 'GET' -Headers @{} -ContentType 'application/json' `
                    -ErrorVariable errRec -ErrorAction SilentlyContinue
                $errRec | Should -Not -BeNullOrEmpty
            }
        }

        It 'Writes an error when Invoke-RestMethod throws a general exception' {
            Mock Invoke-RestMethod { throw 'Unexpected error' } -ModuleName PoshKelvin

            InModuleScope PoshKelvin {
                $errRec = $null
                _GetPaginatedData -Uri 'https://kelvin.example.com/api/v4/test' `
                    -Method 'GET' -Headers @{} -ContentType 'application/json' `
                    -ErrorVariable errRec -ErrorAction SilentlyContinue
                $errRec | Should -Not -BeNullOrEmpty
            }
        }
    }
}
