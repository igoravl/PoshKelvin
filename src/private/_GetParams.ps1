<#
.SYNOPSIS
    Derives query parameters for an API call from the caller's bound parameters.
.DESCRIPTION
    This function inspects the calling command via the PowerShell call stack and uses
    its InvocationInfo.BoundParameters and parameter metadata to construct a hashtable
    of query parameters. It selects only parameters that belong to the 'Query' parameter
    set and that were explicitly bound by the caller, then maps each to its query name
    (preferring the first alias when available). Parameters that were not supplied or
    have a value of $null are omitted so they are not sent to the API.
#>
Function _GetParams {

    $caller = (Get-PSCallStack)[1]
    $invocationInfo = $caller.InvocationInfo
    $callerCommand = $invocationInfo.MyCommand
    $boundParameters = $invocationInfo.BoundParameters

    $allParams = $callerCommand.Parameters.Values `
    | Where-Object { $_.ParameterSets.Keys -contains 'Query' } `
    | Where-Object { $boundParameters.Keys -contains $_.Name }
    
    $result = @{}

    foreach ($parm in $allParams) {

        $key = $parm.Name
        $val = $boundParameters[$key]
        $parmName = _GetParamName $parm

        if ($null -eq $val) { continue }

        $result[$parmName] = $val
    }

    return $result
}

Function _GetParamName ($parm) {

    $paramName = $parm.Name.ToLower()

    if ($parm.Aliases.Count -gt 0) {
        $paramName = $parm.Aliases[0].ToLower()
    }

    return $paramName
}
