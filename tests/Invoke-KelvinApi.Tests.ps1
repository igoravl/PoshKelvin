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
                $script:KelvinURL   = $null
                $script:KelvinToken = $null
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
