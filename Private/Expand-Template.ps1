<#
    .SYNOPSIS
        Expands template placeholders in a string using values from a context object.

    .DESCRIPTION
        Replaces all template expressions of the form {{ property }} or {{ property.subproperty }} in the input string with corresponding values from the provided context object. If a context value is missing, replaces the placeholder with an empty string and writes a verbose message using Write-VerboseMark.

    .PARAMETER Content
        The template string containing placeholders to expand.

    .PARAMETER Context
        The object providing values for template placeholders. Supports nested properties using dot notation.

    .EXAMPLE
        Expand-Template -Content 'Hello, {{ user.name }}!' -Context @{ user = @{ name = 'World' } }

    .NOTES
        - Missing context values are replaced with an empty string and a verbose message is written.
        - Uses Write-VerboseMark for verbose output on missing values.
#>
function Expand-Template {
    param([string]$Content, $Context)
    $Content -replace '{{\s*([\w.]+)\s*}}', {
        $expr = $_.Groups[1].Value
        $parts = $expr -split '\.'
        $val = $Context
        foreach ($p in $parts) {
            if ($null -eq $val) { break }
            $val = $val.$p
        } 
        if ($null -eq $val) { 
            Write-VerboseMark "Missing context value for '$expr'. Returning empty string."
            return '' 
        } else { 
            return $val.ToString() 
        }
    }
}
