function _TestSensitiveHeader {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Name
    )

    $Name = $Name.Trim()
    return ($Name -in @('Cookie', 'Cookie2', 'Set-Cookie', 'Set-Cookie2')) -or ($Name -like 'Sec-*')
}

function _SelectResponseHeaders {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        # Header collections (dictionaries or HttpHeaders) to search, in priority order.
        [Parameter()]
        [AllowNull()]
        [object[]] $Headers,

        # The header names to select. Sensitive headers are always excluded.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]] $Name
    )

    $selected = [ordered]@{}
    foreach ($headerName in $Name) {
        if ([string]::IsNullOrWhiteSpace($headerName) -or (_TestSensitiveHeader $headerName)) {
            continue
        }
        $headerName = $headerName.Trim()
        if ($selected.Contains($headerName)) {
            continue
        }

        foreach ($collection in $Headers) {
            if ($null -eq $collection) {
                continue
            }
            $entries = if ($collection -is [System.Collections.IDictionary]) { $collection.GetEnumerator() } else { $collection }
            $match = $entries | Where-Object { $_.Key -eq $headerName } | Select-Object -First 1
            if ($null -ne $match) {
                $selected[$headerName] = [string]::Join(', ', [string[]] @($match.Value))
                break
            }
        }
    }

    return $selected
}

function _AddResponseHeaders {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary] $Headers
    )

    $copy = [ordered]@{}
    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $copy[$key] = $Headers[$key]
        }
    }
    return Add-Member -InputObject $InputObject -NotePropertyName '_headers' -NotePropertyValue $copy -Force -PassThru
}
