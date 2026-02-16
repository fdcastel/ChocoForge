function Expand-Template {
    <#
    .SYNOPSIS
        Expands template placeholders in a string using values from a context object.

    .DESCRIPTION
        Replaces all template expressions of the form {{ property }} or {{ property.subproperty }} in the input string with
        corresponding values from the provided context object. Supports both simple and nested properties using dot notation.

        If a context value is missing, the placeholder is replaced with an empty string.

        For placeholders ending in '.sha256' (e.g., {{ asset.sha256 }}):

        - if the parent object contains a 'digest' property starting with 'sha256:', it will extract the SHA256 value from there.

        - if the parent object contains a 'browser_download_url' property, the function will automatically download the file,
          calculate its SHA256 hash, and cache the result for 24 hours.

        Returns the expanded string with all placeholders replaced.

    .PARAMETER Content
        The template string containing placeholders to expand.

    .PARAMETER Context
        The object providing values for template placeholders. Supports nested properties using dot notation.

    .EXAMPLE
        Expand-Template -Content 'Hello, {{ user.name }}!' -Context @{ user = @{ name = 'World' } }

    .EXAMPLE
        Expand-Template -Content 'SHA256: {{ asset.sha256 }}' -Context @{ asset = @{ browser_download_url = 'https://example.com/file.zip' } }

    .OUTPUTS
        System.String. The expanded string with all placeholders replaced.
    #>
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
            $lastPart = $parts[-1]
            if ($lastPart -eq 'sha256' -and $parts.Count -gt 1) {
                # Special handling for sha256 placeholders
                $parentParts = $parts[0..($parts.Count - 2)]
                $parentVal = $Context
                foreach ($pp in $parentParts) {
                    if ($null -eq $parentVal) { break }
                    $parentVal = $parentVal.$pp
                }

                if ($null -ne $parentVal -and $null -ne $parentVal.digest -and $parentVal.digest.StartsWith('sha256:')) {
                    $sha256 = $parentVal.digest.Substring(7)
                    Write-VerboseMark "Using sha256 from digest property: $sha256"
                    return $sha256
                }

                if ($null -ne $parentVal -and $null -ne $parentVal.browser_download_url -and $parentVal.browser_download_url -ne '') {
                    return Get-Sha256FromUrlWithCache -Url $parentVal.browser_download_url
                }
            }
            return ''
        } else {
            return $val.ToString()
        }
    }
}
