#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/_TestHelpers.ps1"
    Import-Module $script:ModulePath -Force
    Set-KelvinTestConnection
}

Describe 'Small collection defaults' -ForEach @(
    @{ Command = 'Get-KelvinDataStreamUnit'; Arguments = @{}; Endpoint = 'datastreams/units/list'; ExpectedPaginationMode = 'Cursor' }
    @{ Command = 'Get-KelvinAppResource'; Arguments = @{ AppName = 'my-app' }; Endpoint = 'app-manager/app/my-app/resources/list' }
    @{ Command = 'Get-KelvinAssetType'; Arguments = @{}; Endpoint = 'assets/types/list' }
    @{ Command = 'Get-KelvinDataStream'; Arguments = @{}; Endpoint = 'datastreams/list' }
    @{ Command = 'Get-KelvinFile'; Arguments = @{}; Endpoint = 'filestorage/list' }
    @{ Command = 'Get-KelvinInstanceSetting'; Arguments = @{}; Endpoint = 'instance/settings/list' }
    @{ Command = 'Get-KelvinClusterNode'; Arguments = @{ ClusterName = 'my-cluster' }; Endpoint = 'orchestration/clusters/my-cluster/nodes/list' }
) {
    BeforeEach {
        Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
    }

    It '<Command> retains its existing pagination default' {
        & $Command @Arguments
        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Path -eq $Endpoint -and
            (($ExpectedPaginationMode -and $PaginationMode -eq $ExpectedPaginationMode) -or
                (-not $ExpectedPaginationMode -and -not $PaginationMode)) -and
            -not $AsStream
        }
    }
}

Describe 'Streaming collection defaults' -ForEach @(
    @{ Command = 'Get-KelvinWorkload'; Arguments = @{}; Endpoint = 'workloads/list'; Method = 'GET'; ExpectedType = 'Kelvin.Workload'; DetailPath = 'workloads/sample/get' }
    @{ Command = 'Get-KelvinAsset'; Arguments = @{}; Endpoint = 'assets/list'; Method = 'GET'; ExpectedType = 'Kelvin.Asset'; DetailPath = 'assets/sample/get' }
    @{ Command = 'Get-KelvinAuditLog'; Arguments = @{}; Endpoint = 'instance/auditlog/list'; Method = 'GET'; ExpectedType = 'Kelvin.AuditLog'; DetailPath = 'instance/auditlog/sample/get' }
    @{ Command = 'Get-KelvinApp'; Arguments = @{}; Endpoint = 'appregistry/list'; Method = 'GET'; ExpectedType = 'Kelvin.App'; DetailPath = 'appregistry/sample/get' }
    @{ Command = 'Get-KelvinCluster'; Arguments = @{}; Endpoint = 'orchestration/clusters/list'; Method = 'GET'; ExpectedType = 'Kelvin.Cluster'; DetailPath = 'orchestration/clusters/sample/get' }
    @{ Command = 'Get-KelvinSecret'; Arguments = @{}; Endpoint = 'secrets/list'; Method = 'GET'; ExpectedType = 'Kelvin.Secret'; DetailPath = $null }
) {
    BeforeEach {
        Mock Invoke-KelvinApi {
            [pscustomobject]@{ name = 'sample'; id = 'sample'; status = [pscustomobject]@{ state = 'running' } }
        } -ModuleName PoshKelvin
    }

    It '<Command> selects parsed streaming by default and preserves output' {
        $result = @(& $Command @Arguments)
        $result.Count | Should -Be 1
        $result[0].name | Should -Be 'sample'
        if ($Command -eq 'Get-KelvinWorkload') {
            $result[0].state | Should -Be 'running'
        }
        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Path -eq $Endpoint -and $Method -eq $ExpectedMethod -and
            $TypeName -eq $ExpectedType -and $PaginationMode -eq 'Stream' -and -not $AsStream
        }
    }

    BeforeAll {
        $ExpectedMethod = $Method
    }

    It '<Command> forwards an explicit <Mode> mode without leaking it into query filters' -ForEach @(
        @{ Mode = 'Cursor' }
        @{ Mode = 'Limits' }
        @{ Mode = 'Stream' }
    ) {
        & $Command @Arguments -PaginationMode $Mode
        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Path -eq $Endpoint -and $PaginationMode -eq $Mode -and
            -not $Parameters.ContainsKey('paginationmode') -and
            -not $Parameters.ContainsKey('pagination_type')
        }
    }

    It '<Command> rejects an unsupported pagination mode' {
        { & $Command @Arguments -PaginationMode Invalid } | Should -Throw
        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 0 -Exactly
    }

    It '<Command> emits each result before the next one is produced' {
        $received = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-KelvinApi {
            [pscustomobject]@{ name = 'first'; status = [pscustomobject]@{ state = 'running' } }
            $received.Count | Should -Be 1
            [pscustomobject]@{ name = 'second'; status = [pscustomobject]@{ state = 'stopped' } }
        } -ModuleName PoshKelvin

        & $Command @Arguments | ForEach-Object { $received.Add($_) }

        $received.Count | Should -Be 2
        $received[0].name | Should -Be 'first'
        $received[1].name | Should -Be 'second'
    }

    It '<Command> leaves detail requests unpaginated' -Skip:($null -eq $DetailPath) {
        & $Command @Arguments -Detailed -PaginationMode Limits
        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Path -eq $Endpoint -and $PaginationMode -eq 'Limits'
        }
        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Path -eq $DetailPath -and -not $PaginationMode -and -not $AsStream
        }
    }
}

Describe 'Streaming list filter preservation' {
    BeforeEach {
        Mock Invoke-KelvinApi { } -ModuleName PoshKelvin
    }

    It 'Preserves workload pipeline filters and explicit false values' {
        [pscustomobject]@{ cluster_name = 'my-cluster' } |
            Get-KelvinWorkload -Enabled $false -PaginationMode Stream

        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Parameters.cluster_name -eq 'my-cluster' -and
            $Parameters.ContainsKey('enabled') -and $Parameters.enabled -eq $false -and
            $PaginationMode -eq 'Stream' -and -not $Parameters.ContainsKey('paginationmode')
        }
    }

    It 'Preserves asset filters and aliases' {
        Get-KelvinAsset -Name sample -AssetType pump -Status online

        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Parameters.names -eq 'sample' -and $Parameters.asset_type -eq 'pump' -and
            $Parameters.status -eq 'online' -and $PaginationMode -eq 'Stream'
        }
    }

    It 'Preserves application filters' {
        Get-KelvinApp -Name sample -Type docker

        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Parameters.name -eq 'sample' -and $Parameters.type -eq 'docker' -and
            $PaginationMode -eq 'Stream'
        }
    }

    It 'Preserves cluster filters and explicit false values' {
        Get-KelvinCluster -Name sample -Ready $false -Status online

        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Parameters.names -eq 'sample' -and
            $Parameters.ContainsKey('ready') -and $Parameters.ready -eq $false -and
            $Parameters.status -eq 'online' -and $PaginationMode -eq 'Stream' -and
            -not $Parameters.ContainsKey('paginationmode')
        }
    }

    It 'Preserves audit log time range serialization' {
        $start = [datetime]::new(2026, 10, 1, 0, 0, 0, [DateTimeKind]::Utc)
        $end = $start.AddDays(1)
        Get-KelvinAuditLog -StartTime $start -EndTime $end

        Should -Invoke Invoke-KelvinApi -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter {
            $Parameters.start_time -eq $start.ToString('o') -and
            $Parameters.end_time -eq $end.ToString('o') -and $PaginationMode -eq 'Stream'
        }
    }
}
