function Expand-EnvironmentVariables {
    <#
    .SYNOPSIS
        Expands ${VARNAME} in a string with the value of the environment variable VARNAME.
    .DESCRIPTION
        Expansion is all-or-nothing: if any referenced variable is unset, $null is returned rather
        than a partially expanded string. A partial result such as 'prefix-' is truthy and would
        otherwise be mistaken for a valid value by callers.
    .PARAMETER InputString
        The string to expand.
    .OUTPUTS
        [string] The expanded string, or $null if any referenced variable is not set.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$InputString
    )

    $pattern = '\$\{([A-Za-z_][A-Za-z0-9_]*)\}'

    # Resolve every referenced variable up front, so a miss can abort before building a
    # half-substituted string.
    $values = @{}
    foreach ($match in [regex]::Matches($InputString, $pattern)) {
        $varName = $match.Groups[1].Value
        if ($values.ContainsKey($varName)) { continue }

        $envValue = [Environment]::GetEnvironmentVariable($varName)
        if (-not $envValue) {
            Write-VerboseMark "Environment variable '$varName' is required but not set."
            return $null
        }
        Write-VerboseMark -Message "Expanding environment variable $varName."
        $values[$varName] = $envValue
    }

    return $InputString -replace $pattern, { $values[$_.Groups[1].Value] }
}
