function _GetPaginatedData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [uri]$Uri,
        
        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [string]$ContentType,

        [Parameter()]
        [hashtable]$Headers,

        [Parameter()]
        $TypeName
    )

    $currentUri = $Uri
    $pageCount = 1
    
    do {
        try {
            Write-Verbose "Requesting data from $currentUri"
            
            $response = Invoke-RestMethod -Uri $currentUri -Method $Method -Body $Body `
                -ContentType $ContentType -Headers $Headers -ErrorAction Stop

            if ($response.PSObject.Properties.Name -contains 'pagination') {
                Write-Verbose "Pagination detected. Processing page $pageCount"
                Write-Verbose $response.pagination | ConvertTo-Json -Compress

                try {
                    $response.data | ForEach-Object {
                        $item = $_
                        if ($TypeName) {
                            $_.PSObject.TypeNames.Insert(0, $TypeName)
                        }
                        Write-Output $item
                    }
                }
                catch {
                    Write-Error "Failed to process page $pageCount data: $($_.Exception.Message)"
                    return
                }
                
                if ($response.pagination.next_page) {
                    try {
                        Add-Type -AssemblyName System.Web
                        $builder = [UriBuilder]$Uri
                        $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
                        $query['next'] = $response.pagination.next_page
                        $query['previous'] = $response.pagination.previous_page
                        $builder.Query = $query.ToString()
                        $currentUri = $builder.Uri
                        $pageCount++
                    }
                    catch {
                        Write-Error "Failed to build pagination URL: $($_.Exception.Message)"
                        return
                    }
                }
                else {
                    $currentUri = $null
                }
            }
            else {
                Write-Output $response
                $currentUri = $null
            }
        }
        catch [System.Net.WebException] {
            Write-Error "HTTP request failed on page $pageCount`: $_"
            return
        }
        catch {
            Write-Error "Unexpected error on page $pageCount`: $_"
            return
        }
    } while ($currentUri)
}
