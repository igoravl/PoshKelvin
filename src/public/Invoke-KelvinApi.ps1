<#
.SYNOPSIS
    Invokes a Kelvin API endpoint.

.DESCRIPTION
    Sends a request to a Kelvin API endpoint. Handles authentication, pagination,
    JSON serialization, and query-string building. Requires a prior call to
    Connect-KelvinAccount.

.EXAMPLE
    PS> Invoke-KelvinApi 'workloads/list'

    Sends a GET request to the workloads/list endpoint.

.EXAMPLE
    PS> Invoke-KelvinApi 'workloads/apply' -Method POST -Body @{ workload_names = @('w1','w2') }

    Sends a POST request with a JSON body.

.EXAMPLE
    PS> Invoke-KelvinApi 'workloads/my-app/download' -Accept 'application/zip' -AsStream

    Returns the raw response stream for binary content.
#>
function Invoke-KelvinApi {
    [CmdletBinding()]
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

        # When specified, returns the raw response stream instead of parsed objects.
        [Parameter()]
        [switch]$AsStream
    )

    if (-not $script:KelvinURL -or -not $script:KelvinToken) {
        throw 'Connect-KelvinAccount must be called before invoking any API commands.'
    }

    $url = "$script:KelvinURL/$Path"
    Write-Verbose "Invoking API at $url"

    if ($Body -is [string] -or $Body -is [int] -or $Body -is [double]) {
        $requestBody = $Body
    }
    elseif ($null -ne $Body) {
        $requestBody = $Body | ConvertTo-Json -Depth 10
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
        $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $script:KelvinToken)
        $client.DefaultRequestHeaders.Accept.Add((New-Object System.Net.Http.Headers.MediaTypeWithQualityHeaderValue($Accept)))
        $client.DefaultRequestHeaders.Add('User-Agent', 'PoshKelvin/1.0')
        
        $request = New-Object System.Net.Http.HttpRequestMessage -ArgumentList $Method, $url
        $request.Content = $(if ($requestBody) { New-Object System.Net.Http.StringContent($requestBody, [System.Text.Encoding]::UTF8, $BodyContentType) })

        $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        
        if ($response.IsSuccessStatusCode) {
            return $response.Content.ReadAsStreamAsync().Result
        }
        else {
            throw "Failed to invoke API: $($response.ReasonPhrase) - $($response.Content.ReadAsStringAsync().Result)"
        }
    }

    return _GetPaginatedData -Uri $url `
        -Method $Method `
        -Body $requestBody `
        -ContentType $BodyContentType `
        -Headers @{ Authorization = "Bearer $script:KelvinToken" } `
        -TypeName $TypeName
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
