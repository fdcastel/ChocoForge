function Get-Sha256FromUrlWithCache {
    <#
    .SYNOPSIS
        Downloads a file from a URL, calculates its SHA256 hash, and caches the result for 24 hours.

    .DESCRIPTION
        Downloads the file at the specified URL to a temporary location, calculates its SHA256 hash,
        and caches the hash in a JSON file in the user's TEMP directory. If a cached hash exists and
        is less than 24 hours old, the cached value is returned.

    .PARAMETER Url
        The URL of the file to download and hash.

    .EXAMPLE
        Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip'

    .OUTPUTS
        System.String. The lowercase SHA256 hash of the file.
    #>
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
            $cache = @{}
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
