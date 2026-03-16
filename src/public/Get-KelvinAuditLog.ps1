<#
.SYNOPSIS
    Gets audit logs from Kelvin.

.DESCRIPTION
    Retrieves audit logs from the currently connected Kelvin instance.
    Supports filtering by user, action, resource, and time range.

.EXAMPLE
    PS> Get-KelvinAuditLog

    Lists all audit log entries.

.EXAMPLE
    PS> Get-KelvinAuditLog -User admin -StartTime (Get-Date).AddDays(-7)

    Lists audit log entries from the last 7 days for the 'admin' user.
#>
Function Get-KelvinAuditLog {
    [OutputType('Kelvin.AuditLog')]
    [CmdletBinding()]
    Param
    (
        # Free-form text search across audit log fields.
        [Parameter(Position = 0)]
        [string[]] $Search,

        # Filter by audit log entry ID.
        [Parameter()]
        [Alias('audit_logger_id')]
        [string[]] $Id,

        # Filter by the user who performed the action.
        [Parameter()]
        [string[]] $User,

        # Filter by action type.
        [Parameter()]
        [string[]] $Action,

        # Filter by resource name.
        [Parameter()]
        [string[]] $Resource,

        # Return only entries after this date/time.
        [Parameter()]
        [DateTime] $StartTime,

        # Return only entries before this date/time.
        [Parameter()]
        [DateTime] $EndTime,

        # Return detailed information for each entry.
        [Parameter()]
        [switch] $Detailed
    )

    Process {
        $params = _GetParams

        # Convert DateTime objects to ISO 8601 strings if provided
        if ($StartTime) {
            $params['start_time'] = $StartTime.ToString('o')
        }

        if ($EndTime) {
            $params['end_time'] = $EndTime.ToString('o')
        }

        Invoke-KelvinApi 'instance/auditlog/list' -Method Get -TypeName 'Kelvin.AuditLog' -Parameters $params `
        | ForEach-Object {
            if ($Detailed.IsPresent) {
                $ret = (Invoke-KelvinApi "instance/auditlog/$($_.id)/get" -Method Get -TypeName 'Kelvin.AuditLog')
            }
            else {
                $ret = $_
            }
            Write-Output $ret
        }
    }
}
