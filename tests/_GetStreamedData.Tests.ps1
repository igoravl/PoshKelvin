#Requires -Module Pester

Describe 'Streaming HTTP requests' {
    BeforeAll {
        . "$PSScriptRoot/_TestHelpers.ps1"
        Import-Module $script:ModulePath -Force

        $acknowledgement = Join-Path $TestDrive 'first-record-read'
        $stopServer = Join-Path $TestDrive 'stop-server'
        $server = Start-Job -ArgumentList $acknowledgement, $stopServer -ScriptBlock {
            param ($Acknowledgement, $StopServer)
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
            $listener.Start()
            $listener.LocalEndpoint.Port
            try {
                while (-not (Test-Path $StopServer)) {
                    if (-not $listener.Pending()) {
                        Start-Sleep -Milliseconds 20
                        continue
                    }
                    $connection = $listener.AcceptTcpClient()
                    $stream = $connection.GetStream()
                    $reader = [System.IO.StreamReader]::new($stream)
                    $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
                    $writer.NewLine = "`r`n"
                    $writer.AutoFlush = $true
                    try {
                        $requestLine = $reader.ReadLine()
                        $path = $requestLine.Split(' ')[1].Split('?')[0]
                        $length = 0
                        $authorization = ''
                        while ($header = $reader.ReadLine()) {
                            if ($header -match '^Content-Length: (\d+)') { $length = [int] $Matches[1] }
                            if ($header -match '^Authorization: (.+)') { $authorization = $Matches[1] }
                        }
                        $body = [char[]]::new($length)
                        $offset = 0
                        while ($offset -lt $length) {
                            $count = $reader.Read($body, $offset, $length - $offset)
                            if ($count -eq 0) { throw 'Request body ended prematurely.' }
                            $offset += $count
                        }
                        $status = if ($path -eq '/always401' -or
                            ($path.StartsWith('/unauthorized') -and $authorization -ne 'Bearer fresh-token')) {
                            '401 Unauthorized'
                        }
                        elseif ($path -eq '/forbidden') { '403 Forbidden' }
                        elseif ($path -eq '/error') { '400 Bad Request' }
                        else { '200 OK' }
                        $writer.WriteLine("HTTP/1.1 $status")
                        $writer.WriteLine('Content-Type: application/x-json-stream')
                        $writer.WriteLine('X-Request-Id: stream-request')
                        $writer.WriteLine('Set-Cookie: session=secret')
                        $writer.WriteLine('Sec-Test: secret')
                        $writer.WriteLine('Connection: close')
                        $writer.WriteLine()
                        if ($status -eq '401 Unauthorized') {
                            $writer.WriteLine('{"detail":"unauthorized"}')
                        }
                        elseif ($status -eq '403 Forbidden') {
                            $writer.WriteLine('{"detail":"forbidden"}')
                        }
                        elseif ($path -eq '/error') {
                            $writer.WriteLine('{"detail":"invalid filter"}')
                        }
                        elseif ($path -eq '/bad') {
                            $writer.WriteLine('not-json')
                        }
                        elseif ($path -eq '/post' -or $path -eq '/unauthorized-post') {
                            $writer.WriteLine((@{ method = $requestLine.Split(' ')[0]; body = -join $body } | ConvertTo-Json -Compress))
                        }
                        elseif ($path -eq '/unauthorized-json') {
                            $writer.WriteLine('{"id":1}')
                        }
                        else {
                            $writer.WriteLine('{"id":1}')
                            if ($path -eq '/partial-bad') {
                                $writer.WriteLine('not-json')
                                continue
                            }
                            if ($path -eq '/incremental') {
                                $deadline = [DateTime]::UtcNow.AddSeconds(10)
                                while (-not (Test-Path $Acknowledgement) -and [DateTime]::UtcNow -lt $deadline) {
                                    Start-Sleep -Milliseconds 50
                                }
                                if (-not (Test-Path $Acknowledgement)) {
                                    $writer.WriteLine('not-json')
                                    continue
                                }
                            }
                            $writer.WriteLine()
                            $writer.WriteLine('{"id":2}')
                        }
                    }
                    finally {
                        $writer.Dispose()
                        $reader.Dispose()
                        $connection.Dispose()
                    }
                }
            }
            finally { $listener.Stop() }
        }
        $port = $null
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        while (-not $port -and [DateTime]::UtcNow -lt $deadline) {
            $port = Receive-Job $server
            if (-not $port) { Start-Sleep -Milliseconds 100 }
        }
        if (-not $port) { throw 'The local stream test server did not start.' }
        $baseUri = "http://127.0.0.1:$port"
    }

    AfterAll {
        if ($server) {
            Set-Content -Path $stopServer -Value 'stop'
            $null = Wait-Job $server -Timeout 15
            if ($server.State -notin @('Completed', 'Failed', 'Stopped')) {
                Stop-Job $server
            }
            Remove-Job $server
        }
    }

    Context 'Incremental JSON stream reader' {
        It 'Emits the first typed record before the server sends the second' {
            $results = @(& (Get-Module PoshKelvin) {
                param ($Uri)
                _GetStreamedData -Uri $Uri -Method GET -Headers @{} -TypeName Kelvin.StreamItem
            } "$baseUri/incremental" | ForEach-Object {
                if ($_.id -eq 1) { Set-Content -Path $acknowledgement -Value 'ready' }
                $_
            })
            $results.Count | Should -Be 2
            $results[0].id | Should -Be 1
            $results[1].id | Should -Be 2
            $results[0].PSObject.TypeNames | Should -Contain Kelvin.StreamItem
        }

        It 'Attaches selected response and content headers to each record' {
            $results = @(& (Get-Module PoshKelvin) {
                param ($Uri)
                _GetStreamedData -Uri $Uri -Method GET -Headers @{} `
                    -IncludeHeaders 'x-request-id', 'Content-Type', 'Set-Cookie', 'Sec-Test'
            } "$baseUri/records")
            $results.Count | Should -Be 2
            foreach ($result in $results) {
                $result._headers['x-request-id'] | Should -Be 'stream-request'
                $result._headers['Content-Type'] | Should -Be 'application/x-json-stream'
                $result._headers.Count | Should -Be 2
                $result.PSObject.Properties.Name | Should -Not -Contain '$headers'
            }
        }

        It 'Preserves POST method and JSON request body' {
            $result = & (Get-Module PoshKelvin) {
                param ($Uri)
                _GetStreamedData -Uri $Uri -Method POST -Body '{"names":["sample"]}' `
                    -ContentType application/json -Headers @{}
            } "$baseUri/post"
            $result.method | Should -Be POST
            $result.body | Should -Be '{"names":["sample"]}'
        }

        It 'Reports malformed stream records' {
            { & (Get-Module PoshKelvin) {
                param ($Uri)
                _GetStreamedData -Uri $Uri -Method GET -Headers @{}
            } "$baseUri/bad" } | Should -Throw '*Invalid JSON in stream record 1*'
        }

        It 'Reports HTTP status and server error details' {
            { & (Get-Module PoshKelvin) {
                param ($Uri)
                _GetStreamedData -Uri $Uri -Method GET -Headers @{}
            } "$baseUri/error" } | Should -Throw '*HTTP 400*invalid filter*'
        }
    }

    Context 'HTTP 401 recovery across response modes' {
        BeforeEach {
            Set-KelvinTestConnection
            & (Get-Module PoshKelvin) { param ($Url) $script:KelvinSession.Url = $Url } $baseUri
            Mock _GetToken {
                if ($Renew) { 'fresh-token' } else { 'test-bearer-token' }
            } -ModuleName PoshKelvin
        }

        It 'Retries an Invoke-RestMethod request with a renewed token' {
            (Invoke-KelvinApi unauthorized-json -ErrorAction Stop).id | Should -Be 1
            Should -Invoke _GetToken -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter { $Renew }
        }

        It 'Retries a request with selected headers using a renewed token' {
            $result = Invoke-KelvinApi unauthorized-json -IncludeHeaders 'X-Request-Id', 'Set-Cookie' `
                -ErrorAction Stop -WarningAction SilentlyContinue
            $result.id | Should -Be 1
            $result._headers['X-Request-Id'] | Should -Be 'stream-request'
            $result._headers.Contains('Set-Cookie') | Should -BeFalse
            Should -Invoke _GetToken -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter { $Renew }
        }

        It 'Attaches selected headers to streamed records from Invoke-KelvinApi' {
            $result = @(Invoke-KelvinApi records -PaginationMode Stream -IncludeHeaders 'X-Request-Id' -ErrorAction Stop)
            $result.Count | Should -Be 2
            $result[1]._headers['X-Request-Id'] | Should -Be 'stream-request'
        }

        It 'Retries a rejected JSON stream selected through <Selection> before emitting any records' -ForEach @(
            @{ Selection = 'PaginationMode'; Arguments = @{ PaginationMode = 'Stream' } }
            @{ Selection = 'Parameters'; Arguments = @{ Parameters = @{ pagination_type = 'stream' } } }
        ) {
            $result = @(Invoke-KelvinApi unauthorized @Arguments -TypeName Kelvin.Test -ErrorAction Stop)
            $result.Count | Should -Be 2
            $result[0].id | Should -Be 1
            $result[1].id | Should -Be 2
            $result[0].PSObject.TypeNames[0] | Should -Be 'Kelvin.Test'
            Should -Invoke _GetToken -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter { $Renew }
        }

        It 'Preserves POST body and method when retrying a JSON stream' {
            $result = Invoke-KelvinApi unauthorized-post -Method POST -Body @{ names = @('sample') } `
                -PaginationMode Stream -ErrorAction Stop
            $result.method | Should -Be POST
            ($result.body | ConvertFrom-Json).names[0] | Should -Be sample
            Should -Invoke _GetToken -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter { $Renew }
        }

        It 'Retries a rejected raw download before returning the stream' {
            $stream = Invoke-KelvinApi unauthorized -AsStream -ErrorAction Stop
            $reader = [System.IO.StreamReader]::new($stream)
            try { ($reader.ReadLine() | ConvertFrom-Json).id | Should -Be 1 }
            finally { $reader.Dispose() }
            Should -Invoke _GetToken -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter { $Renew }
        }

        It 'Stops after the second 401 for <Mode>' -TestCases @(
            @{ Mode = 'json' }
            @{ Mode = 'stream' }
            @{ Mode = 'raw' }
        ) {
            param ($Mode)
            $arguments = @{ Path = 'always401'; ErrorAction = 'Stop' }
            if ($Mode -eq 'stream') { $arguments.Parameters = @{ pagination_type = 'stream' } }
            if ($Mode -eq 'raw') { $arguments.AsStream = $true }
            { Invoke-KelvinApi @arguments } | Should -Throw '*401*'
            Should -Invoke _GetToken -ModuleName PoshKelvin -Times 1 -Exactly -ParameterFilter { $Renew }
        }

        It 'Does not renew on HTTP 403 for <Mode>' -TestCases @(
            @{ Mode = 'json' }
            @{ Mode = 'stream' }
            @{ Mode = 'raw' }
        ) {
            param ($Mode)
            $arguments = @{ Path = 'forbidden'; ErrorAction = 'Stop' }
            if ($Mode -eq 'stream') { $arguments.Parameters = @{ pagination_type = 'stream' } }
            if ($Mode -eq 'raw') { $arguments.AsStream = $true }
            { Invoke-KelvinApi @arguments } | Should -Throw '*403*'
            Should -Invoke _GetToken -ModuleName PoshKelvin -Times 0 -Exactly -ParameterFilter { $Renew }
        }

        It 'Does not retry malformed stream records' {
            { Invoke-KelvinApi bad -Parameters @{ pagination_type = 'stream' } -ErrorAction Stop } |
                Should -Throw '*Invalid JSON*'
            Should -Invoke _GetToken -ModuleName PoshKelvin -Times 0 -Exactly -ParameterFilter { $Renew }
        }

        It 'Does not replay a stream after a record has already been emitted' {
            $items = [System.Collections.Generic.List[object]]::new()
            { Invoke-KelvinApi partial-bad -Parameters @{ pagination_type = 'stream' } -ErrorAction Stop |
                ForEach-Object { $items.Add($_) } } | Should -Throw '*stream record 2*'
            $items.Count | Should -Be 1
            $items[0].id | Should -Be 1
            Should -Invoke _GetToken -ModuleName PoshKelvin -Times 0 -Exactly -ParameterFilter { $Renew }
        }
    }
}
