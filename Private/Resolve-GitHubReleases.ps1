function Resolve-GitHubReleases {
    <#
    .SYNOPSIS
        Adds a 'version' property to each GitHub release object and optionally filters and transforms assets.

    .DESCRIPTION
        Processes an array of GitHub release objects (from Find-GitHubReleases), extracting a version from each release using a regex pattern or script block. 
        
        Optionally filters releases by minimum version. 
        
        If an asset pattern is provided, only matching assets are included and named capture groups are added as properties. 
        
        If a transpose property is specified, the assets array is converted to a hashtable keyed by that property.

    .PARAMETER InputObject
        The array of release objects to process (output of Find-GitHubReleases).

    .PARAMETER VersionPattern
        Optional. Regex pattern with a capture group to extract the version from tag_name. If both VersionPattern and VersionScriptBlock are provided, VersionPattern is used for matching and VersionScriptBlock for formatting the version string.

    .PARAMETER VersionScriptBlock
        Optional. Script block to construct the version string from $Matches after a successful pattern match. Used only if VersionPattern is provided and matches.

    .PARAMETER MinimumVersion
        Optional. Only releases with version greater than or equal to this value are included. Requires either VersionPattern or VersionScriptBlock.

    .PARAMETER AssetPattern
        Optional. Regex pattern with named capture groups to extract asset attributes. Only assets matching the pattern are included, and named groups are added as properties.

    .PARAMETER TransposeProperty
        Optional. If provided, the assets array is converted to a hashtable keyed by this property, and the key property is removed from each asset object in the output.

    .EXAMPLE
        $expanded = Find-GitHubReleases ... | Resolve-GitHubReleases -VersionPattern 'T(\d+)_(\d+)_(\d+)' -VersionScriptBlock { "$($Matches[1]).$($Matches[2]).$($Matches[3])" } -MinimumVersion '4.0.0' -AssetPattern 'Firebird-[\\d.]+-\\d+-(?<platform>[^-]+)-(?<arch>[^-]+)(-(?<debug>withDebugSymbols))?\\.(?!zip$)[^.]+$' -TransposeProperty 'arch'

    .OUTPUTS
        PSCustomObject[]
        An array of release objects with added version and asset properties, optionally filtered and transformed.
    #>
    [CmdletBinding(DefaultParameterSetName = 'NoVersion')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'NoVersion')]
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'VersionPattern')]
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'VersionScriptBlock')]
        [object]$InputObject,

        [Parameter(ParameterSetName = 'VersionPattern')]
        [string]$VersionPattern,

        [Parameter(ParameterSetName = 'VersionScriptBlock')]
        [scriptblock]$VersionScriptBlock,

        [Parameter(ParameterSetName = 'VersionPattern')]
        [Parameter(ParameterSetName = 'VersionScriptBlock')]
        [version]$MinimumVersion,

        [Parameter(ParameterSetName = 'NoVersion')]
        [Parameter(ParameterSetName = 'VersionPattern')]
        [Parameter(ParameterSetName = 'VersionScriptBlock')]
        [string]$AssetPattern,

        [Parameter(ParameterSetName = 'NoVersion')]
        [Parameter(ParameterSetName = 'VersionPattern')]
        [Parameter(ParameterSetName = 'VersionScriptBlock')]
        [string]$TransposeProperty
    )

    process {
        $result = @()
        foreach ($release in $InputObject) {
            $version = $null
            $matched = $true
            
            if ($PSBoundParameters.ContainsKey('OptionalScript')) {
                $version = & $VersionScriptBlock
                $matched = $null -ne $version
            } elseif ($VersionPattern) {
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
                        $asset.PSObject.Properties.Remove('arch')
                        $ht[$($g.Name)] = $asset
                    }
                    $ht
                }
            }
        }

        return $result
    }
}
