#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe 'Pagination modes and request continuity' {
    It 'Preserves the <Method> body and query filters while following cursor pages' -TestCases @(
        @{ Method = 'GET' }
        @{ Method = 'POST' }
    ) {
        param ($Method)
        Mock Invoke-RestMethod {
            $lastPage = $Uri.Query -match 'next='
            [PSCustomObject]@{
                data = @([PSCustomObject]@{ id = $(if ($lastPage) { 2 } else { 1 }); method = $Method })
                pagination = [PSCustomObject]@{
                    next_page = $(if (-not $lastPage) { 'a+b/=' })
                    previous_page = 'backward'
                }
            }
        } -ModuleName PoshKelvin

        $results = & (Get-Module PoshKelvin) {
            param ($Method)
            _GetPaginatedData -Uri 'https://kelvin.example.com/api/v4/assets/list?search=a%20b&page_size=1&previous=old' `
                -Method $Method -Body '{"names":["example"]}' -ContentType 'application/json'
        } $Method

        $results.Count | Should -Be 2
        $results[0].method | Should -Be $Method
        $results[1].method | Should -Be $Method
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 2 -Exactly -ParameterFilter {
            $Body -eq '{"names":["example"]}' -and $Uri.Query -match 'page_size=1' -and
            [System.Web.HttpUtility]::ParseQueryString($Uri.Query)['search'] -eq 'a b'
        }
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Uri.Query -match 'next=a%2bb%2f%3d' -and $Uri.Query -notmatch 'previous='
        }
    }

    It 'Follows all limits pages for <Method> and refreshes authorization before every page' -TestCases @(
        @{ Method = 'GET' }
        @{ Method = 'POST' }
    ) {
        param ($Method)
        Mock _GetToken { 'fresh-token' } -ModuleName PoshKelvin
        Mock Invoke-RestMethod {
            $page = [System.Web.HttpUtility]::ParseQueryString($Uri.Query)['page']
            if (-not $page) { $page = 1 }
            [PSCustomObject]@{
                data = @([PSCustomObject]@{ id = [int] $page; method = $Method })
                pagination = [PSCustomObject]@{ page = [int] $page; total_pages = 3; page_size = 1 }
            }
        } -ModuleName PoshKelvin
        $results = & (Get-Module PoshKelvin) {
            param ($Method)
            _GetPaginatedData -Uri 'https://kelvin.example.com/api/v4/assets/list?pagination_type=limits&page_size=1' `
                -Method $Method -Body '{}' -Headers @{ Accept = 'application/json' } -RefreshToken -TypeName Kelvin.Asset
        } $Method

        $results.Count | Should -Be 3
        foreach ($item in $results) {
            $item.PSObject.TypeNames | Should -Contain 'Kelvin.Asset'
            $item.method | Should -Be $Method
        }
        Should -Invoke _GetToken -ModuleName PoshKelvin -Times 3 -Exactly
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Uri.Query -match 'page=2' -and $Headers.Authorization -eq 'Bearer fresh-token' -and $Body -eq '{}'
        }
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Uri.Query -match 'page=3' -and $Headers.Authorization -eq 'Bearer fresh-token'
        }
    }

    It 'Stops on repeated cursors instead of looping indefinitely' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ data = @(); pagination = [PSCustomObject]@{ next_page = 'same' } }
        } -ModuleName PoshKelvin

        { & (Get-Module PoshKelvin) {
            _GetPaginatedData -Uri 'https://kelvin.example.com/list' -Method GET -ErrorAction Stop
        } } | Should -Throw '*previously requested page*'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 2 -Exactly
    }

    It 'Retries only the rejected <Mode> page for <Method>' -TestCases @(
        @{ Mode = 'cursor'; Method = 'GET' }
        @{ Mode = 'cursor'; Method = 'POST' }
        @{ Mode = 'limits'; Method = 'GET' }
        @{ Mode = 'limits'; Method = 'POST' }
    ) {
        param ($Mode, $Method)
        Mock _GetToken {
            if ($Renew) { 'fresh-token' } else { 'test-bearer-token' }
        } -ModuleName PoshKelvin
        Mock Invoke-RestMethod {
            $query = [System.Web.HttpUtility]::ParseQueryString($Uri.Query)
            $secondPage = $query['next'] -eq 'two' -or $query['page'] -eq '2'
            if ($secondPage -and $Headers.Authorization -ne 'Bearer fresh-token') {
                $failure = [System.Exception]::new('Unauthorized')
                $failure.Data['StatusCode'] = 401
                throw $failure
            }
            $page = if ($secondPage) { 2 } else { 1 }
            $pagination = if ($query['pagination_type'] -eq 'limits') {
                [PSCustomObject]@{ page = $page; total_pages = 2 }
            }
            else {
                [PSCustomObject]@{ next_page = $(if (-not $secondPage) { 'two' }) }
            }
            [PSCustomObject]@{
                data = @([PSCustomObject]@{ id = $page; method = $Method; body = $Body })
                pagination = $pagination
            }
        } -ModuleName PoshKelvin
        $results = @(& (Get-Module PoshKelvin) {
            param ($Mode, $Method)
            _GetPaginatedData -Uri "https://kelvin.example.com/list?pagination_type=$Mode" `
                -Method $Method -Body '{"filter":"sample"}' -RefreshToken -ErrorAction Stop
        } $Mode $Method)

        $results.Count | Should -Be 2
        $results[0].id | Should -Be 1
        $results[1].id | Should -Be 2
        $results[1].method | Should -Be $Method
        $results[1].body | Should -Be '{"filter":"sample"}'
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 3 -Exactly
        Should -Invoke _GetToken -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter { $Renew }
    }

    It 'Handles a final cursor page that omits optional next_page metadata' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{
                data = @([PSCustomObject]@{ id = 1 })
                pagination = [PSCustomObject]@{ previous_page = 'back' }
            }
        } -ModuleName PoshKelvin
        $result = & (Get-Module PoshKelvin) {
            _GetPaginatedData -Uri 'https://kelvin.example.com/list' -Method GET
        }
        $result.id | Should -Be 1
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly
    }

    It 'Types non-paginated responses as well as paginated ones' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ id = 1 }
        } -ModuleName PoshKelvin
        $result = & (Get-Module PoshKelvin) {
            _GetPaginatedData -Uri 'https://kelvin.example.com/item' -Method GET -TypeName Kelvin.Single
        }
        $result.PSObject.TypeNames | Should -Contain Kelvin.Single
    }

    It 'Stops when limits metadata does not match the requested page' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ data = @(); pagination = [PSCustomObject]@{ page = 1; total_pages = 3 } }
        } -ModuleName PoshKelvin

        { & (Get-Module PoshKelvin) {
            _GetPaginatedData -Uri 'https://kelvin.example.com/list?pagination_type=limits&page=2' -Method GET -ErrorAction Stop
        } } | Should -Throw '*does not match*'
    }

    It 'Handles empty limits results without another request' {
        Mock Invoke-RestMethod {
            [PSCustomObject]@{ data = @(); pagination = [PSCustomObject]@{ page = 1; total_pages = 0 } }
        } -ModuleName PoshKelvin
        $result = @(& (Get-Module PoshKelvin) {
            _GetPaginatedData -Uri 'https://kelvin.example.com/list?pagination_type=limits' -Method GET
        })
        $result.Count | Should -Be 0
        Should -Invoke Invoke-RestMethod -ModuleName PoshKelvin -Times 1 -Exactly
    }

    It 'Preserves the underlying HTTP exception and response details' {
        Mock Invoke-RestMethod {
            $record = [System.Management.Automation.ErrorRecord]::new(
                [System.Net.WebException]::new('HTTP failure'), 'KelvinFailure',
                [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
            $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"detail":"invalid filter"}')
            throw $record
        } -ModuleName PoshKelvin

        $failure = $null
        try {
            & (Get-Module PoshKelvin) {
                _GetPaginatedData -Uri 'https://kelvin.example.com/list' -Method POST -ErrorAction Stop
            }
        }
        catch { $failure = $_ }
        $failure.Exception | Should -BeOfType ([System.Net.WebException])
        $failure.ErrorDetails.Message | Should -BeLike '*page 1*POST*invalid filter*'
    }

    It 'Routes stream mode to the incremental reader and preserves method, body, and types' {
        Mock _GetStreamedData { [PSCustomObject]@{ id = 1 } } -ModuleName PoshKelvin
        & (Get-Module PoshKelvin) {
            _GetPaginatedData -Uri 'https://kelvin.example.com/list?pagination_type=stream' `
                -Method POST -Body '{}' -Headers @{} -TypeName Kelvin.Asset
        } | Out-Null

        Should -Invoke _GetStreamedData -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and $Body -eq '{}' -and $TypeName -eq 'Kelvin.Asset' -and
            $Headers.Accept -eq 'application/x-json-stream'
        }
    }

    It 'Enables stream pagination when selected through Accept alone' {
        Mock _GetStreamedData { } -ModuleName PoshKelvin
        & (Get-Module PoshKelvin) {
            _GetPaginatedData -Uri 'https://kelvin.example.com/list?search=example' `
                -Method GET -Headers @{ Accept = 'application/x-json-stream' }
        }
        Should -Invoke _GetStreamedData -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Uri.Query -match 'pagination_type=stream' -and $Uri.Query -match 'search=example'
        }
    }
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
