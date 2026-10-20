#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    if (-not ('KelvinTestWebResponse' -as [type])) {
        Add-Type @'
public sealed class KelvinTestWebResponse : System.Net.WebResponse {
    public System.Net.HttpStatusCode StatusCode {
        get { return System.Net.HttpStatusCode.Unauthorized; }
    }
}
'@
    }
}

Describe 'Authenticated request recovery' {
    It 'Recognizes the Windows PowerShell WebException response shape' {
        Mock _GetToken { 'fresh-token' } -ModuleName PoshKelvin
        $result = & (Get-Module PoshKelvin) {
            _InvokeAuthenticatedRequest -Headers @{ Authorization = 'Bearer old' } -RefreshToken -Request {
                param ($headers)
                if ($headers.Authorization -ne 'Bearer fresh-token') {
                    throw [System.Net.WebException]::new('Unauthorized', $null,
                        [System.Net.WebExceptionStatus]::ProtocolError, [KelvinTestWebResponse]::new())
                }
                'success'
            }
        }
        $result | Should -Be success
        Should -Invoke _GetToken -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter { $Renew }
    }

    It 'Surfaces token renewal failure without replaying the request' {
        Mock _GetToken { throw 'Renewal failed' } -ModuleName PoshKelvin
        $attempts = [System.Collections.Generic.List[int]]::new()
        { & (Get-Module PoshKelvin) {
            param ($Attempts)
            _InvokeAuthenticatedRequest -Headers @{} -RefreshToken -Request {
                $Attempts.Add(1)
                $failure = [System.Exception]::new('Unauthorized')
                $failure.Data['StatusCode'] = 401
                throw $failure
            }
        } $attempts } | Should -Throw '*Renewal failed*'
        $attempts.Count | Should -Be 1
    }

    It 'Does not mistake an error message mentioning 401 for an HTTP status' {
        Mock _GetToken { throw 'Must not be called' } -ModuleName PoshKelvin
        { & (Get-Module PoshKelvin) {
            _InvokeAuthenticatedRequest -Headers @{} -RefreshToken -Request { throw 'Record 401 failed to parse' }
        } } | Should -Throw '*Record 401 failed*'
        Should -Invoke _GetToken -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Does not refresh requests without module authentication enabled' {
        Mock _GetToken { throw 'Must not be called' } -ModuleName PoshKelvin
        { & (Get-Module PoshKelvin) {
            _InvokeAuthenticatedRequest -Headers @{} -Request {
                $failure = [System.Exception]::new('Unauthorized')
                $failure.Data['StatusCode'] = 401
                throw $failure
            }
        } } | Should -Throw '*Unauthorized*'
        Should -Invoke _GetToken -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It 'Does not retry HTTP <StatusCode>' -TestCases @(
        @{ StatusCode = 400 }
        @{ StatusCode = 500 }
    ) {
        param ($StatusCode)
        Mock _GetToken { throw 'Must not be called' } -ModuleName PoshKelvin
        { & (Get-Module PoshKelvin) {
            param ($Code)
            _InvokeAuthenticatedRequest -Headers @{} -RefreshToken -Request {
                $failure = [System.Exception]::new("HTTP $Code")
                $failure.Data['StatusCode'] = $Code
                throw $failure
            }
        } $StatusCode } | Should -Throw "*HTTP $StatusCode*"
        Should -Invoke _GetToken -ModuleName PoshKelvin -Times 0 -Exactly
    }
}
