function Expand-GitHubReleases {
    <#
    .SYNOPSIS
        Adds a 'version' property to each GitHub release object and optionally filters by minimum version. Optionally extracts asset attributes using a regex with named capture groups.

    .DESCRIPTION
        Receives the output of Get-GitHubReleases. Adds a 'version' property to each release, extracted from 'tag_name' using a regex pattern if provided. Optionally filters to only include releases with version greater than or equal to -MinimumVersion. If -VersionFormatScriptBlock is provided, it is used to construct the version string from regex matches. If -AssetPattern is provided, each asset is matched against the pattern and all named capture groups are added as properties. Assets that do not match are excluded.

    .PARAMETER InputObject
        The array of release objects (output of Get-GitHubReleases).

    .PARAMETER VersionPattern
        Optional. Regex pattern with a capture group to extract the version from tag_name. If not provided, tag_name is used as-is.

    .PARAMETER VersionFormatScriptBlock
        Optional. Script block to construct the version string from $Matches after a successful pattern match.

    .PARAMETER MinimumVersion
        Optional. Only releases with version greater than or equal to this value are included. Uses [version] comparison.

    .PARAMETER AssetPattern
        Optional. Regex pattern with named capture groups to extract asset attributes (e.g. platform, arch, debug). Only assets matching the pattern are included.

    .EXAMPLE
        $expanded = Get-GitHubReleases ... | Expand-GitHubReleases -VersionPattern 'T(\d+)_(\d+)_(\d+)' -VersionFormatScriptBlock { "$($Matches[1]).$($Matches[2]).$($Matches[3])" } -MinimumVersion '4.0.0' -AssetPattern 'Firebird-[\d.]+-\d+-(?<platform>[^-]+)-(?<arch>[^-]+)(-(?<debug>withDebugSymbols))?\.(?!zip$)[^.]+$'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,
        [string]$VersionPattern,
        [scriptblock]$VersionFormatScriptBlock,
        [string]$MinimumVersion,
        [string]$AssetPattern
    )

    process {
        $valid = @()
        foreach ($release in $InputObject) {
            $version = $null
            $matched = $false
            if ($VersionPattern) {
                if ($release.tag_name -match $VersionPattern) {
                    $matched = $true
                    if ($VersionFormatScriptBlock) {
                        $version = & $VersionFormatScriptBlock
                    } else {
                        $version = $Matches[1]
                    }
                }
            } else {
                $matched = $true
                $version = $release.tag_name
            }
            if ($matched) {
                $release | Add-Member -NotePropertyName 'version' -NotePropertyValue $version -Force
                # Asset attribute extraction using named capture groups
                # If -AssetPattern is provided, only keep assets that match the pattern
                # For each asset, if the name matches, add all named capture groups as properties
                if ($AssetPattern -and $release.PSObject.Properties['assets']) {
                    $filteredAssets = @()
                    foreach ($asset in $release.assets) {
                        if ($asset.name -match $AssetPattern) {
                            # Extract named capture groups and add them as properties
                            $namedGroups = [regex]::Matches($AssetPattern, '\(\?<([a-zA-Z_][a-zA-Z0-9_]*)>') | ForEach-Object { $_.Groups[1].Value }
                            foreach ($key in $namedGroups) {
                                $value = if ($Matches.ContainsKey($key)) { $Matches[$key] } else { $null }
                                $asset | Add-Member -NotePropertyName $key -NotePropertyValue $value -Force
                            }
                            $filteredAssets += $asset
                        }
                        # If the asset does not match, it is excluded
                    }
                    $release.assets = $filteredAssets
                }
                $valid += $release
            }
        }
        $filtered = $valid
        if ($MinimumVersion) {
            $filtered = $filtered | Where-Object { [version]$_.version -ge [version]$MinimumVersion }
        }
        $filtered
    }
}
