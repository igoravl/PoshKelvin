function _InvokeAuthenticatedRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [scriptblock] $Request,

        [Parameter(Mandatory)]
        [hashtable] $Headers,

        [Parameter()]
        [switch] $RefreshToken
    )

    try {
        & $Request $Headers
    }
    catch {
        # Invoke-RestMethod exposes Response on both WebException (5.1) and HttpResponseException (7+).
        $statusCode = $_.Exception.Response.StatusCode
        if ($null -eq $statusCode) {
            $statusCode = $_.Exception.Data['StatusCode']
        }
        if (-not $RefreshToken -or $statusCode -ne 401) {
            throw
        }

        Write-Verbose 'HTTP 401 received. Renewing the access token and retrying the rejected request once.'
        $Headers.Authorization = "Bearer $(_GetToken -Renew)"
        & $Request $Headers
    }
}
