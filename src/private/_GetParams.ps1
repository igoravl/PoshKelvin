<#
.SYNOPSIS
    This function is used to extract parameters from a hashtable based on a mapping.
.DESCRIPTION
    The function takes a hashtable of bound parameters and a mapping hashtable.
    It returns a new hashtable containing only the parameters that are present in the mapping.
    This way, parameters not supplied by the user are not passed to the API call.
#>
Function _GetParams ($BP, $Map) {

    if ($Map) {
        $result = @{}
        foreach ($key in $Map.Keys) {
            $val = $Map[$key]
            if ($null -ne $val) {
                $result[$key] = $val
            }
        }
        return $result
    }
    
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
