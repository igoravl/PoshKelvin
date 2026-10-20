function _GetJwtClaims {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # The JWT whose payload is decoded. The signature is NOT validated; claims are only used as metadata.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Token
    )

    $parts = $Token.Split('.')
    if ($parts.Count -ne 3 -or -not $parts[1]) {
        Write-Verbose 'The token is not a JWT. No claims were decoded.'
        return $null
    }

    try {
        $payload = $parts[1].Replace('-', '+').Replace('_', '/')
        switch ($payload.Length % 4) {
            2 { $payload += '==' }
            3 { $payload += '=' }
        }

        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
        return ($json | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        Write-Verbose "Unable to decode the JWT payload: $($_.Exception.Message)"
        return $null
    }
}
