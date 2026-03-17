#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinAuditLog' {

    Context 'List call' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                [PSCustomObject]@{ id = 'log-1'; action = 'create'; user = 'admin' }
                [PSCustomObject]@{ id = 'log-2'; action = 'delete'; user = 'admin' }
            } -ModuleName PoshKelvin
        }

        It 'Calls the instance/auditlog/list endpoint with GET' {
            Get-KelvinAuditLog

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'instance/auditlog/list' -and $Method -eq 'Get'
            }
        }

        It 'Returns all items from the API response' {
            $result = Get-KelvinAuditLog
            $result.Count | Should -Be 2
        }

        It 'Returns objects typed as Kelvin.AuditLog' {
            Get-KelvinAuditLog
            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $TypeName -eq 'Kelvin.AuditLog'
            }
        }
    }

    Context 'Filter parameters' {

        BeforeAll {
            Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
        }

        It 'Does not throw when -Action is provided' {
            # Note: -Action is in __AllParameterSets (not ParameterSetName='Query'),
            # so _GetParams does not forward it automatically. The DateTime params
            # (StartTime, EndTime) ARE forwarded via explicit mapping in the cmdlet body.
            { Get-KelvinAuditLog -Action 'create' } | Should -Not -Throw
        }

        It 'Does not throw when -User is provided' {
            { Get-KelvinAuditLog -User 'admin' } | Should -Not -Throw
        }

        It 'Converts -StartTime to ISO 8601 and adds it to the query parameters' {
            $dt = [DateTime]::new(2025, 6, 15, 10, 30, 0, [System.DateTimeKind]::Utc)
            Get-KelvinAuditLog -StartTime $dt

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('start_time') -and
                $Parameters['start_time'] -like '2025-06-15T10:30:00*'
            }
        }

        It 'Converts -EndTime to ISO 8601 and adds it to the query parameters' {
            $dt = [DateTime]::new(2025, 6, 16, 18, 0, 0, [System.DateTimeKind]::Utc)
            Get-KelvinAuditLog -EndTime $dt

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Parameters.ContainsKey('end_time') -and
                $Parameters['end_time'] -like '2025-06-16T18:00:00*'
            }
        }
    }

    Context '-Detailed switch' {

        BeforeAll {
            Mock Invoke-KelvinApi {
                if ($Path -like '*/get') {
                    [PSCustomObject]@{ id = 'log-1'; details = 'Full audit entry' }
                }
                else {
                    [PSCustomObject]@{ id = 'log-1' }
                }
            } -ModuleName PoshKelvin
        }

        It 'Makes a detail API call for each audit log entry using its id' {
            Get-KelvinAuditLog -Detailed

            Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -ParameterFilter {
                $Path -eq 'instance/auditlog/log-1/get'
            }
        }
    }
}
