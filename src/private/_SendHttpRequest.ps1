function _SendHttpRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Net.Http.HttpClient] $Client,

        [Parameter(Mandatory)]
        [uri] $Uri,

        [Parameter(Mandatory)]
        [string] $Method,

        [Parameter(Mandatory)]
        [hashtable] $Headers,

        [Parameter()]
        [object] $Body,

        [Parameter()]
        [string] $ContentType
    )

    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $Uri)
    $response = $null
    try {
        foreach ($key in $Headers.Keys) {
            $null = $request.Headers.TryAddWithoutValidation($key, [string] $Headers[$key])
        }
        if ($null -ne $Body) {
            $request.Content = [System.Net.Http.StringContent]::new([string] $Body, [System.Text.Encoding]::UTF8, $ContentType)
        }
        $response = $Client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            $details = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $failure = [System.Net.Http.HttpRequestException]::new(
                "HTTP $([int] $response.StatusCode) ($($response.ReasonPhrase)): $details")
            $failure.Data['StatusCode'] = [int] $response.StatusCode
            throw $failure
        }
        $response
    }
    catch {
        if ($response) { $response.Dispose() }
        throw
    }
    finally { $request.Dispose() }
}
