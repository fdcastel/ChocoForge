<#
    .SYNOPSIS
        Expands template placeholders in a string using values from a context object.

    .DESCRIPTION
        Replaces all template expressions of the form {{ property }} or {{ property.subproperty }} in the input string with 
        corresponding values from the provided context object. Supports both simple and nested properties using dot notation.
        
        If a context value is missing, the placeholder is replaced with an empty string.

        For placeholders ending in '.sha256' (e.g., {{ asset.sha256 }}), if the parent object contains a 'browser_download_url' 
        property, the function will automatically download the file, calculate its SHA256 hash, and cache the result for 24 hours. 

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
            $lastPart = $parts[-1]
            if ($lastPart -eq 'sha256' -and $parts.Count -gt 1) {
                # Special handling for sha256 placeholders
                $parentParts = $parts[0..($parts.Count - 2)]
                $parentVal = $Context
                foreach ($pp in $parentParts) {
                    if ($null -eq $parentVal) { break }
                    $parentVal = $parentVal.$pp
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

<#+
.SYNOPSIS
    Downloads a file from a URL, calculates its SHA256 hash, and caches the result for 24 hours.
.DESCRIPTION
    Downloads the file at the specified URL to a temporary location, calculates its SHA256 hash, and caches the hash in a JSON file in the user's TEMP directory. If a cached hash exists and is less than 24 hours old, the cached value is returned. Verbose messages are always written for cache usage, cache errors, downloads, and hash calculations using Write-VerboseMark.
.PARAMETER Url
    The URL of the file to download and hash.
.EXAMPLE
    Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip'
.NOTES
    Used internally by Expand-Template for {{ ...sha256 }} placeholders. Not intended for direct use outside template expansion.
    Verbose output is always written using Write-VerboseMark.
#>
function Get-Sha256FromUrlWithCache {
    param([string]$Url)
    $url = $Url.Trim()
    $cachePath = Join-Path $env:TEMP 'ChocoForge-HashCache.json'
    $cache = @{}
    if (Test-Path $cachePath) {
        try {
            $rawCache = Get-Content $cachePath -Raw | ConvertFrom-Json
            if ($rawCache -is [System.Collections.IDictionary]) {
                foreach ($k in $rawCache.PSObject.Properties.Name) { $cache[$k] = $rawCache.$k }
            } elseif ($rawCache -is [PSCustomObject]) {
                foreach ($k in $rawCache.PSObject.Properties.Name) { $cache[$k] = $rawCache.$k }
            } else {
                $cache = @{}
            }
        } catch {
            Write-VerboseMark 'Failed to read or parse cache file. Starting with empty cache.'
            $cache = @{
            }
        }
    }
    $now = Get-Date
    $cacheKey = $url
    $cachedEntry = $null
    if ($cache.Keys -contains $cacheKey) {
        $cachedEntry = $cache[$cacheKey]
        $cacheTime = Get-Date $cachedEntry.timestamp
        if ($now - $cacheTime -lt ([TimeSpan]::FromHours(24))) {
            Write-VerboseMark "Using cached SHA256 for $url."
            return $cachedEntry.sha256
        } else {
            Write-VerboseMark "Cache expired for $url. Recomputing hash."
        }
    }
    $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    $fileName = Split-Path $url -Leaf
    $filePath = Join-Path $tempDir $fileName
    Write-VerboseMark "Downloading $url to $filePath ..."
    Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing -Verbose:$false
    Write-VerboseMark "Calculating SHA256 for $filePath ..."
    $sha256 = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()
    Remove-Item -Path $tempDir -Recurse -Force
    $cache[$cacheKey] = @{ sha256 = $sha256; timestamp = $now.ToString('o') }
    try {
        $cache | ConvertTo-Json -Depth 5 | Set-Content -Path $cachePath -Force
        Write-VerboseMark "Wrote SHA256 to cache for $url."
    } catch { 
        Write-VerboseMark 'Failed to write cache file.' 
    }
    Write-VerboseMark "Returning calculated SHA256 for $url."
    return $sha256
}
