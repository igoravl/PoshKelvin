function _GetPaginatedData {
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
        [hashtable] $Headers = @{},

        [Parameter()]
        [string] $TypeName,

        [Parameter()]
        [switch] $RefreshToken
    )

    $builder = [UriBuilder] $Uri
    Add-Type -AssemblyName System.Web
    $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
    $streaming = $query['pagination_type'] -eq 'stream' -or $Headers.Accept -eq 'application/x-json-stream'

    $requestHeaders = $Headers.Clone()

    if ($streaming) {
        $query['pagination_type'] = 'stream'
        $builder.Query = $query.ToString()
        $Uri = $builder.Uri
        $requestHeaders.Accept = 'application/x-json-stream'
    }

    $currentUri = $Uri
    $pageCount = 0
    $visited = [System.Collections.Generic.HashSet[string]]::new()

    do {
        try {
            if (-not $visited.Add($currentUri.AbsoluteUri)) {
                throw 'Pagination returned a previously requested page. Stopping to avoid an infinite loop.'
            }

            $pageCount++
            if ($RefreshToken) {
                $requestHeaders.Authorization = "Bearer $(_GetToken)"
            }
            Write-Verbose "Requesting page $pageCount using $Method $currentUri"

            if ($streaming) {
                Write-Verbose 'Reading newline-delimited JSON stream.'
                _GetStreamedData -Uri $currentUri -Method $Method -Body $Body `
                    -ContentType $ContentType -Headers $requestHeaders -TypeName $TypeName `
                    -RefreshToken:$RefreshToken -ErrorAction Stop
                return
            }

            $response = _InvokeAuthenticatedRequest -Headers $requestHeaders -RefreshToken:$RefreshToken -Request {
                param ($headers)
                Invoke-RestMethod -Uri $currentUri -Method $Method -Body $Body `
                    -ContentType $ContentType -Headers $headers -ErrorAction Stop
            }

            $paginated = $null -ne $response -and $response.PSObject.Properties.Name -contains 'pagination'
            if ($paginated) {
                Write-Verbose ($response.pagination | ConvertTo-Json -Compress)
                $items = $response.data
                $pagination = $response.pagination
                if ($null -eq $pagination) {
                    throw 'The response contains null pagination metadata.'
                }

                if ($pagination.PSObject.Properties.Name -contains 'next_page' -or
                    $pagination.PSObject.Properties.Name -contains 'previous_page' -or
                    @($pagination.PSObject.Properties).Count -eq 0) {
                    $paginationMode = 'cursor'
                }
                elseif ($pagination.PSObject.Properties.Name -contains 'total_pages') {
                    $paginationMode = 'limits'
                    $page = 0
                    $totalPages = 0
                    if (-not [int]::TryParse([string] $pagination.page, [ref] $page) -or $page -lt 1 -or
                        -not [int]::TryParse([string] $pagination.total_pages, [ref] $totalPages) -or $totalPages -lt 0) {
                        throw 'The response contains invalid limits pagination metadata.'
                    }
                    if ($query['page'] -and $page -ne [int] $query['page']) {
                        throw 'The response page does not match the requested page.'
                    }
                }
                else {
                    throw 'The response contains unsupported pagination metadata.'
                }
            }
            else {
                $items = $response
            }

            foreach ($item in $items) {
                if ($null -ne $item) {
                    if ($TypeName) {
                        $item.PSObject.TypeNames.Insert(0, $TypeName)
                    }
                    Write-Output $item
                }
            }

            if (-not $paginated) {
                return
            }

            if ($paginationMode -eq 'cursor') {
                if (-not $pagination.next_page) {
                    return
                }
                # Forward navigation must never send a backward cursor.
                $query.Remove('previous')
                $query['next'] = $pagination.next_page
            }
            else {
                if ($page -ge $totalPages) {
                    return
                }
                $query.Remove('next')
                $query.Remove('previous')
                $query['pagination_type'] = 'limits'
                $query['page'] = [string] ($page + 1)
            }
            $builder.Query = $query.ToString()
            $currentUri = $builder.Uri
        }
        catch {
            $details = $_.Exception.Message
            if ($_.ErrorDetails.Message) {
                $details = "$details $($_.ErrorDetails.Message)"
            }
            $_.ErrorDetails = [System.Management.Automation.ErrorDetails]::new(
                "Request failed on page $pageCount ($Method $currentUri): $details")
            $PSCmdlet.WriteError($_)
            return
        }
    } while ($currentUri)
}
