function Resolve-GitHubReleases {
    <#
    .SYNOPSIS
        Adds a 'version' property to each GitHub release object and optionally filters and transforms assets.

    .DESCRIPTION
        Processes an array of GitHub release objects (from Find-GitHubReleases), extracting a version from each release
        using a regex pattern.

        Optionally filters releases by minimum version.

        If an asset pattern is provided, only matching assets are included and named capture groups are added as properties.

        If a transpose property is specified, the assets array is converted to a hashtable keyed by that property.

    .PARAMETER InputObject
        The array of release objects to process (output of Find-GitHubReleases).

    .PARAMETER VersionPattern
        Regex pattern with a capture group to extract the version from tag_name.

    .PARAMETER MinimumVersion
        Optional. Only releases with version greater than or equal to this value are included.

    .PARAMETER AssetPattern
        Optional. Regex pattern with named capture groups to extract asset attributes. Only assets matching the pattern
        are included, and named groups are added as properties.

    .PARAMETER TransposeProperty
        Optional. If provided, the assets array is converted to a hashtable keyed by this property, and the key property
        is removed from each asset object in the output.

    .EXAMPLE
        $expanded = Find-GitHubReleases ... | Resolve-GitHubReleases -VersionPattern 'v(\d+\.\d+\.\d+)$' -MinimumVersion '4.0.0' -AssetPattern 'Firebird-[\d.]+-\d+-windows-(?<arch>[^-_.]+)\.exe$' -TransposeProperty 'arch'

    .OUTPUTS
        PSCustomObject[]
        An array of release objects with added version and asset properties, optionally filtered and transformed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [Parameter()]
        [string]$VersionPattern,

        [Parameter()]
        [version]$MinimumVersion,

        [Parameter()]
        [string]$AssetPattern,

        [Parameter()]
        [string]$TransposeProperty
    )

    process {
        $result = @()
        foreach ($release in $InputObject) {
            $version = $null
            $matched = $true

            if ($VersionPattern) {
                $matched = $release.tag_name -match $VersionPattern
                $version = $matched ? $Matches[1] : $null
            }

            # If a version is extracted, add it as a property
            if ($null -ne $version) {
                $versionObject = [version]$version
                # If MinimumVersion is provided, filter releases by version
                if ($MinimumVersion -and ($versionObject -lt $MinimumVersion)) {
                    continue
                }

                $release | Add-Member -NotePropertyName 'version' -NotePropertyValue $versionObject -Force
            }

            if ($matched) {                
                # Asset attribute extraction using named capture groups
                #   If -AssetPattern is provided, only keep assets that match the pattern
                #   For each asset, if the name matches, add all named capture groups as properties
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

                    if ($filteredAssets.Count -eq 0) {
                        Write-Warning "Release '$($release.tag_name)' has no assets matching the pattern '$AssetPattern' (AssetPattern too strict?)"
                        continue
                    }
                }
                $result += $release
            }
        }

        # If TransposeProperty is provided, group assets by the specified property
        if ($TransposeProperty) {
            $result = $result | Select-Object 'name', 'version', 'tag_name', 'html_url', 'prerelease', 'published_at', @{
                N = 'assets'
                E = {
                    $grouped = $_.assets | Group-Object -Property $TransposeProperty
                    $ht = @{}
                    foreach ($g in $grouped) {
                        $asset = $g.Group[0].PSObject.Copy()
                        $asset.PSObject.Properties.Remove($TransposeProperty)
                        $ht[$($g.Name)] = $asset
                    }
                    $ht
                }
            }
        }

        return $result
    }
}
