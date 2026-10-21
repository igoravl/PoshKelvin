#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
}

Describe 'Invoke-KelvinApi' {

    Context 'Pre-condition: module connection required' {

        BeforeAll {
            # Clear any existing connection
            & (Get-Module PoshKelvin) {
                $script:KelvinSession = $null
            }
        }

        It 'Throws when Connect-KelvinAccount has not been called' {
            { Invoke-KelvinApi 'some/path' } | Should -Throw '*Connect-KelvinAccount*'
        }
    }

    Context 'URL construction' {

        BeforeAll {
            Set-KelvinTestConnection
            Mock _GetPaginatedData { } -ModuleName PoshKelvin
        }

        It 'Builds the full URL by joining the base URL and the path' {
            Invoke-KelvinApi 'workloads/list'

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Uri -like 'https://kelvin.example.com/api/v4/workloads/list*'
            }
        }

        It 'Appends query string parameters to the URL' {
            Invoke-KelvinApi 'workloads/list' -Parameters @{ search = 'my app' }

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Uri.AbsoluteUri -like '*search=my%20app*'
            }
        }

        It 'Emits multiple query string entries for array parameter values' {
            Invoke-KelvinApi 'workloads/list' -Parameters @{ name = @('w1', 'w2') }

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Uri.AbsoluteUri -like '*name=w1*' -and $Uri.AbsoluteUri -like '*name=w2*'
            }
        }
    }

    Context 'Request body serialization' {

        BeforeAll {
            Set-KelvinTestConnection
            Mock _GetPaginatedData { } -ModuleName PoshKelvin
        }

        It 'Serializes a hashtable body to JSON' {
            Invoke-KelvinApi 'some/path' -Method POST -Body @{ key = 'value' }

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Body -is [string] -and $Body -like '*"key"*' -and $Body -like '*"value"*'
            }
        }

        It 'Passes a string body through without modification' {
            Invoke-KelvinApi 'some/path' -Method POST -Body 'raw-string'

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Body -eq 'raw-string'
            }
        }

        It 'Passes an integer body through without modification' {
            Invoke-KelvinApi 'some/path' -Method POST -Body 42

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Body -eq 42
            }
        }
    }

    Context 'Authorization header' {

        BeforeAll {
            Set-KelvinTestConnection
            Mock _GetPaginatedData { } -ModuleName PoshKelvin
        }

        It 'Sends a Bearer token Authorization header' {
            Invoke-KelvinApi 'some/path'

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Headers.Authorization -eq 'Bearer test-bearer-token'
            }
        }
    }

    Context 'TypeName forwarding' {

        BeforeAll {
            Set-KelvinTestConnection
            Mock _GetPaginatedData { } -ModuleName PoshKelvin
        }

        It 'Passes the TypeName to _GetPaginatedData' {
            Invoke-KelvinApi 'some/path' -TypeName 'Kelvin.TestType'

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.TestType'
            }
        }
    }

    Context 'HTTP method forwarding' {

        BeforeAll {
            Set-KelvinTestConnection
            Mock _GetPaginatedData { } -ModuleName PoshKelvin
        }

        It 'Forwards the GET method to _GetPaginatedData' {
            Invoke-KelvinApi 'some/path' -Method GET

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Method -eq 'GET'
            }
        }

        It 'Forwards the POST method to _GetPaginatedData' {
            Invoke-KelvinApi 'some/path' -Method POST

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Method -eq 'POST'
            }
        }
    }

    Context 'Content-Type and Accept headers' {

        BeforeAll {
            Set-KelvinTestConnection
            Mock _GetPaginatedData { } -ModuleName PoshKelvin
        }

        It 'Uses application/json as the default content type' {
            Invoke-KelvinApi 'some/path' -Method POST -Body @{}

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $ContentType -eq 'application/json'
            }
        }

        It 'Respects a custom -BodyContentType' {
            Invoke-KelvinApi 'some/path' -Method POST -Body 'data' -BodyContentType 'text/plain'

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $ContentType -eq 'text/plain'
            }
        }

        It 'Forwards Accept and enables per-page authentication checks' {
            Invoke-KelvinApi 'assets/list' -Accept 'application/x-json-stream'

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Headers.Accept -eq 'application/x-json-stream' -and $RefreshToken
            }
        }
    }

    Context 'Parsed pagination modes' {

        BeforeAll {
            Set-KelvinTestConnection
            Mock _GetPaginatedData {
                [pscustomobject]@{ name = 'result-item' }
            } -ModuleName PoshKelvin
        }

        It 'Selects <Mode> with its query value and media type' -ForEach @(
            @{ Mode = 'Cursor'; QueryValue = 'cursor'; MediaType = 'application/json-cursor' }
            @{ Mode = 'Limits'; QueryValue = 'limits'; MediaType = 'application/x-json-limits' }
            @{ Mode = 'Stream'; QueryValue = 'stream'; MediaType = 'application/x-json-stream' }
        ) {
            $result = Invoke-KelvinApi 'assets/list' -Method POST -Body @{ names = @('a') } `
                -PaginationMode $Mode -Parameters @{ search = 'my asset' } -TypeName 'Kelvin.Asset'

            $result.name | Should -Be 'result-item'
            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
                $Uri.Query -match "pagination_type=$QueryValue" -and
                $Uri.AbsoluteUri -like '*search=my%20asset*' -and
                $Headers.Accept -eq $MediaType -and
                $Method -eq 'POST' -and ($Body | ConvertFrom-Json).names[0] -eq 'a' -and
                $TypeName -eq 'Kelvin.Asset' -and $RefreshToken
            }
        }

        It 'Preserves the default request when PaginationMode is omitted' {
            Invoke-KelvinApi 'workloads/list'

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Uri -eq 'https://kelvin.example.com/api/v4/workloads/list' -and
                $Headers.Accept -eq 'application/json'
            }
        }

        It 'Preserves legacy query-based selection when PaginationMode is omitted' {
            Invoke-KelvinApi 'workloads/list' -Parameters @{ pagination_type = 'limits'; page_size = 100 }

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Uri.Query -match 'pagination_type=limits' -and $Uri.Query -match 'page_size=100'
            }
        }

        It 'Overrides conflicting query and Accept settings without modifying the caller hashtable' {
            $parameters = @{ pagination_type = 'stream'; page_size = 100; name = @('a', 'b') }
            Invoke-KelvinApi 'workloads/list' -Parameters $parameters `
                -Accept 'application/x-json-stream' -PaginationMode cUrSoR

            $parameters.pagination_type | Should -Be 'stream'
            $parameters.Count | Should -Be 3
            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
                $Uri.Query -match 'pagination_type=cursor' -and
                $Uri.Query -match 'page_size=100' -and
                $Uri.Query -match 'name=a' -and $Uri.Query -match 'name=b' -and
                $Headers.Accept -eq 'application/json-cursor'
            }
        }

        It 'Adds pagination_type only to a copy of the caller hashtable' {
            $parameters = @{ search = 'asset' }
            Invoke-KelvinApi 'assets/list' -Parameters $parameters -PaginationMode Stream
            $parameters.ContainsKey('pagination_type') | Should -BeFalse
        }

        It 'Rejects an unsupported pagination mode' {
            { Invoke-KelvinApi 'workloads/list' -PaginationMode Invalid } | Should -Throw
        }

        It 'Rejects PaginationMode with raw AsStream' {
            { Invoke-KelvinApi 'workloads/list' -PaginationMode Stream -AsStream } | Should -Throw '*parameter set*'
        }
    }

    Context 'Response header selection' {

        BeforeAll {
            Set-KelvinTestConnection
            Mock _GetPaginatedData { } -ModuleName PoshKelvin
        }

        It 'Does not request headers when IncludeHeaders is omitted' {
            Invoke-KelvinApi 'some/path'

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('IncludeHeaders')
            }
        }

        It 'Forwards the selected headers and drops cookies and Sec-* headers' {
            Invoke-KelvinApi 'some/path' -PaginationMode Stream `
                -IncludeHeaders 'X-Request-Id', 'Set-Cookie', 'cookie', 'Sec-Fetch-Mode', ' Content-Type ' `
                -WarningVariable warnings -WarningAction SilentlyContinue

            @($warnings).Count | Should -Be 3
            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
                ($IncludeHeaders -join '|') -eq 'X-Request-Id|Content-Type' -and
                $Uri.Query -match 'pagination_type=stream' -and $IncludeHeaders -notcontains 'pagination_type'
            }
        }

        It 'Still requests a headers map when every selected header is sensitive' {
            Invoke-KelvinApi 'some/path' -IncludeHeaders 'Cookie' -WarningAction SilentlyContinue

            Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
                $null -ne $IncludeHeaders -and $IncludeHeaders.Count -eq 0
            }
        }

        It 'Rejects IncludeHeaders with raw AsStream' {
            { Invoke-KelvinApi 'some/path' -IncludeHeaders 'X-Request-Id' -AsStream } | Should -Throw '*parameter set*'
        }
    }

    Context 'Return value pass-through' {

        BeforeAll {
            Set-KelvinTestConnection
            Mock _GetPaginatedData {
                [PSCustomObject]@{ name = 'result-item' }
            } -ModuleName PoshKelvin
        }

        It 'Returns whatever _GetPaginatedData returns' {
            $result = Invoke-KelvinApi 'some/path'
            $result.name | Should -Be 'result-item'
        }
    }
}

Describe 'Invoke-KelvinApi — _GetQuery helper' {

    BeforeAll {
        Set-KelvinTestConnection
        Mock _GetPaginatedData { } -ModuleName PoshKelvin
    }

    It 'URI-encodes parameter keys and values' {
        Invoke-KelvinApi 'path' -Parameters @{ 'my key' = 'hello world' }

        Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
            $Uri.AbsoluteUri -like '*my%20key=hello%20world*'
        }
    }

    It 'Handles multiple array values for the same key' {
        Invoke-KelvinApi 'path' -Parameters @{ status = @('online', 'offline') }

        Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
            $Uri.AbsoluteUri -like '*status=online*' -and $Uri.AbsoluteUri -like '*status=offline*'
        }
    }

    It 'Handles a mix of scalar and array parameters' {
        Invoke-KelvinApi 'path' -Parameters @{ search = 'foo'; name = @('a', 'b') }

        Should -Invoke _GetPaginatedData -ModuleName PoshKelvin -ParameterFilter {
            $Uri.AbsoluteUri -like '*search=foo*' -and $Uri.AbsoluteUri -like '*name=a*' -and $Uri.AbsoluteUri -like '*name=b*'
        }
    }
}
