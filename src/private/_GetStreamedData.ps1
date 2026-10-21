function _GetStreamedData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [uri] $Uri,

        [Parameter(Mandatory)]
        [string] $Method,

        [Parameter()]
        [object] $Body,

        [Parameter()]
        [string] $ContentType,

        [Parameter()]
        [hashtable] $Headers,

        [Parameter()]
        [string] $TypeName,

        [Parameter()]
        [switch] $RefreshToken,

        # Response header names to attach to each record as an '_headers' property.
        [Parameter()]
        [AllowEmptyCollection()]
        [string[]] $IncludeHeaders
    )

    Add-Type -AssemblyName System.Net.Http
    $client = [System.Net.Http.HttpClient]::new()
    $response = $null
    $reader = $null
    
    try {
        $response = _InvokeAuthenticatedRequest -Headers $Headers -RefreshToken:$RefreshToken -Request {
            param ($requestHeaders)
            _SendHttpRequest -Client $client -Uri $Uri -Method $Method `
                -Headers $requestHeaders -Body $Body -ContentType $ContentType
        }

        if ($null -ne $IncludeHeaders) {
            $responseHeaders = _SelectResponseHeaders -Headers @($response.Headers, $response.Content.Headers) -Name $IncludeHeaders
        }

        $reader = [System.IO.StreamReader]::new($response.Content.ReadAsStreamAsync().GetAwaiter().GetResult())
        $lineNumber = 0
        while ($null -ne ($line = $reader.ReadLine())) {
            $lineNumber++
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            try {
                $items = ConvertFrom-Json -InputObject $line -ErrorAction Stop
            }
            catch {
                throw "Invalid JSON in stream record ${lineNumber}: $($_.Exception.Message)"
            }
            foreach ($item in $items) {
                if ($null -ne $item) {
                    if ($TypeName) {
                        $item.PSObject.TypeNames.Insert(0, $TypeName)
                    }
                    if ($null -ne $IncludeHeaders) {
                        $item = _AddResponseHeaders -InputObject $item -Headers $responseHeaders
                    }
                    Write-Output $item
                }
            }
        }
        Write-Verbose "Finished reading JSON stream ($lineNumber lines)."
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($response) { $response.Dispose() }
        $client.Dispose()
    }
}
