<#
.SYNOPSIS
    Invokes a Kelvin API endpoint.

.DESCRIPTION
    Sends a request to a Kelvin API endpoint. Handles authentication, pagination,
    JSON serialization, and query-string building. Requires a prior call to
    Connect-KelvinAccount. Cursor and limits pagination are followed automatically.
    Use PaginationMode to select Cursor, Limits, or Stream for parsed results.
    When specified, it overrides pagination_type and Accept without modifying the
    caller's parameter hashtable. Otherwise, existing query and header settings
    are preserved (cursor pagination by default). With Stream, newline-delimited
    JSON records are emitted as objects as they arrive.
    Authentication is checked before each page request.
    A request rejected with HTTP 401 is retried once after renewing the token.
    Other errors are not retried. Streams are never replayed after records have
    been emitted.
    Use IncludeHeaders to attach selected response headers to each parsed object
    in an '_headers' property. Cookie and Sec-* headers are always excluded.

.EXAMPLE
    PS> Invoke-KelvinApi 'workloads/list'

    Sends a GET request to the workloads/list endpoint.

.EXAMPLE
    PS> Invoke-KelvinApi 'workloads/apply' -Method POST -Body @{ workload_names = @('w1','w2') }

    Sends a POST request with a JSON body.

.EXAMPLE
    PS> Invoke-KelvinApi 'workloads/my-app/download' -Accept 'application/zip' -AsStream

    Returns the raw response stream for binary content.

.EXAMPLE
    PS> Invoke-KelvinApi 'assets/list' -Method POST -Body @{} -PaginationMode Limits -Parameters @{ page_size = 100 }

    Returns assets from every page, preserving the POST body on each request.

.EXAMPLE
    PS> Invoke-KelvinApi 'assets/list' -PaginationMode Stream

    Parses streamed JSON records into objects. Use -AsStream only for a raw stream.

.EXAMPLE
    PS> $result = Invoke-KelvinApi 'workloads/list' -IncludeHeaders 'Content-Type', 'X-Request-Id'
    PS> $result[0]._headers

    Adds an '_headers' map with the selected response headers to each returned object.
    Cookie and Sec-* headers are never included, even when requested.
#>
function Invoke-KelvinApi {
    [CmdletBinding(DefaultParameterSetName = 'Parsed')]
    param (
        # The API path relative to the base Kelvin URL (e.g. 'workloads/list').
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        # Optional query-string parameters as a hashtable.
        [Parameter(Position = 1)]
        [hashtable]$Parameters,

        # The HTTP method to use. Defaults to GET.
        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
        [string]$Method = 'GET',

        # The request body. Hashtables are automatically serialized to JSON.
        [Parameter()]
        [object]$Body,

        # The Content-Type header for the request body. Defaults to 'application/json'.
        [Parameter()]
        [string]$BodyContentType = 'application/json',

        # The Accept header value. Defaults to 'application/json'.
        [Parameter()]
        [Alias('ContentType')]
        [string]$Accept = 'application/json',

        # A PSTypeName to attach to each returned object.
        [Parameter()]
        [string] $TypeName,

        # Select parsed-result pagination, overriding pagination_type and Accept. Cannot be combined with AsStream.
        [Parameter(ParameterSetName = 'Parsed')]
        [ValidateSet('Cursor', 'Limits', 'Stream')]
        [string] $PaginationMode,

        # Response header names to include in an '_headers' map on each returned object.
        # Cookie and Sec-* headers are always excluded for security reasons. Cannot be combined with AsStream.
        [Parameter(ParameterSetName = 'Parsed')]
        [AllowEmptyCollection()]
        [string[]] $IncludeHeaders,

        # When specified, returns the raw response stream instead of parsed objects.
        [Parameter(ParameterSetName = 'Raw')]
        [switch] $AsStream
    )

    $token = _GetToken

    $url = "$($script:KelvinSession.Url)/$Path"
    Write-Verbose "Invoking API at $url"

    if ($Body -is [string] -or $Body -is [int] -or $Body -is [double]) {
        $requestBody = $Body
    }
    elseif ($null -ne $Body) {
        $requestBody = $Body | ConvertTo-Json -Depth 10
    }

    if ($PSBoundParameters.ContainsKey('PaginationMode')) {
        if ($null -eq $Parameters) {
            $Parameters = @{}
        }
        else {
            $Parameters = $Parameters.Clone()
        }
        $Parameters['pagination_type'] = $PaginationMode.ToLowerInvariant()
        $Accept = switch ($PaginationMode) {
            'Cursor' { 'application/json-cursor' }
            'Limits' { 'application/x-json-limits' }
            'Stream' { 'application/x-json-stream' }
        }
        Write-Verbose "Using parsed-result pagination mode '$PaginationMode' (Accept: $Accept), overriding pagination_type and Accept."
    }

    $headerArguments = @{}
    if ($PSBoundParameters.ContainsKey('IncludeHeaders')) {
        $allowedHeaders = [System.Collections.Generic.List[string]]::new()
        foreach ($headerName in $IncludeHeaders) {
            if ([string]::IsNullOrWhiteSpace($headerName)) {
                continue
            }
            if (_TestSensitiveHeader $headerName) {
                Write-Warning "The '$($headerName.Trim())' header is excluded from the output for security reasons."
                continue
            }
            $allowedHeaders.Add($headerName.Trim())
        }
        $headerArguments.IncludeHeaders = [string[]] $allowedHeaders.ToArray()
    }

    if ($Parameters.Count -gt 0) {
        $urlBuilder = [UriBuilder] $url
        $urlBuilder.Query = _GetQuery $Parameters 
        $url = $urlBuilder.Uri
        Write-Verbose "URL after adding query parameters: $url"
    }

    if ($AsStream) {

        Write-Verbose 'Returning response as a stream.'
        
        Add-Type -AssemblyName System.Net.Http
        $client = New-Object System.Net.Http.HttpClient
        $client.DefaultRequestHeaders.Accept.Add((New-Object System.Net.Http.Headers.MediaTypeWithQualityHeaderValue($Accept)))
        $client.DefaultRequestHeaders.Add('User-Agent', 'PoshKelvin/1.0')
        $response = $null
        try {
            $response = _InvokeAuthenticatedRequest -Headers @{ Authorization = "Bearer $token" } -RefreshToken -Request {
                param ($headers)
                _SendHttpRequest -Client $client -Uri $url -Method $Method `
                    -Headers $headers -Body $requestBody -ContentType $BodyContentType
            }
            return $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        }
        catch {
            if ($response) { $response.Dispose() }
            $client.Dispose()
            throw
        }
    }

    return _GetPaginatedData -Uri $url `
        -Method $Method `
        -Body $requestBody `
        -ContentType $BodyContentType `
        -Headers @{ Authorization = "Bearer $token"; Accept = $Accept } `
        -RefreshToken `
        -TypeName $TypeName `
        @headerArguments
}

function _GetQuery($parameters) {
    $query = @()
    foreach ($key in $parameters.Keys) {
        $encodedKey = [System.Uri]::EscapeDataString($key)
        if ($parameters[$key] -is [array]) {
            foreach ($value in $parameters[$key]) {
                $query += "$encodedKey=$([System.Uri]::EscapeDataString($value))"
            }
        }
        else {
            $query += "$encodedKey=$([System.Uri]::EscapeDataString($parameters[$key]))"
        }
    }
    return [string]::Join('&', $query)
}
