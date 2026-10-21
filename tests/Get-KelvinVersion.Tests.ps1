#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Get-KelvinVersion' {
    BeforeEach {
        Mock Invoke-KelvinApi {
            [PSCustomObject]@{
                version = '1.0.0'
                _headers = @{ 'x-deploy-version' = '5.2.3' }
            }
        } -ModuleName PoshKelvin
    }

    It 'Queries the status endpoint with the deployment version header' {
        Get-KelvinVersion

        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'instance/status/get' -and $Method -eq 'Get' -and
            $IncludeHeaders.Count -eq 1 -and $IncludeHeaders[0] -eq 'x-deploy-version' -and
            $ErrorAction -eq 'Stop'
        }
    }

    It 'Returns exactly one System.Version from the header, not the response body' {
        $result = @(Get-KelvinVersion)

        $result.Count | Should -Be 1
        $result[0] | Should -BeOfType ([System.Version])
        $result[0] | Should -Be ([System.Version] '5.2.3')
    }

    It 'Supports a four-component version' {
        Mock Invoke-KelvinApi {
            [PSCustomObject]@{ _headers = @{ 'x-deploy-version' = '5.2.3.4' } }
        } -ModuleName PoshKelvin

        (Get-KelvinVersion).Revision | Should -Be 4
    }

    It 'Reports a missing or empty version header' -ForEach @(
        @{ HeaderValue = $null }
        @{ HeaderValue = '' }
        @{ HeaderValue = ' ' }
    ) {
        Mock Invoke-KelvinApi {
            [PSCustomObject]@{ _headers = @{ 'x-deploy-version' = $HeaderValue } }
        } -ModuleName PoshKelvin

        { Get-KelvinVersion } | Should -Throw '*missing*x-deploy-version*'
    }

    It 'Reports a missing response' {
        Mock Invoke-KelvinApi { } -ModuleName PoshKelvin

        { Get-KelvinVersion } | Should -Throw '*missing*x-deploy-version*'
    }

    It 'Rejects an invalid System.Version without emitting a result' {
        Mock Invoke-KelvinApi {
            [PSCustomObject]@{ _headers = @{ 'x-deploy-version' = '5.2.3-preview' } }
        } -ModuleName PoshKelvin

        $results = [System.Collections.Generic.List[object]]::new()
        { Get-KelvinVersion | ForEach-Object { $results.Add($_) } } |
            Should -Throw '*not a valid System.Version*'
        $results.Count | Should -Be 0
    }

    It 'Preserves request failures' {
        Mock Invoke-KelvinApi { throw 'Status request failed.' } -ModuleName PoshKelvin

        { Get-KelvinVersion } | Should -Throw '*Status request failed*'
    }
}
