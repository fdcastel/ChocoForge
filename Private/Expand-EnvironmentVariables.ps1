function Expand-EnvironmentVariables {
    <#
    .SYNOPSIS
        Expands ${VARNAME} in a string with the value of the environment variable VARNAME.
    .PARAMETER InputString
        The string to expand.
    .OUTPUTS
        [string] The expanded string.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$InputString
    )
    return $InputString -replace '\$\{([A-Za-z_][A-Za-z0-9_]*)\}', {
        $varName = $_.Groups[1].Value
        $envValue = [Environment]::GetEnvironmentVariable($varName)
        if ($envValue) {
            Write-VerboseMark -Message "Expanding environment variable $varName."
            return $envValue
        } else {
            Write-VerboseMark "Environment variable '$varName' is required but not set."
            return $null
        }
    }
}
