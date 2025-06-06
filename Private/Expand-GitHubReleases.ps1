function Expand-GitHubReleases {
    <#
    .SYNOPSIS
        Adds a 'version' property to each GitHub release object and optionally filters by minimum version.

    .DESCRIPTION
        Receives the output of Get-GitHubReleases. Adds a 'version' property to each release, extracted from 'tag_name' using a regex pattern if provided. Optionally filters to only include releases with version greater than or equal to -MinimumVersion. If -VersionFormatScriptBlock is provided, it is used to construct the version string from regex matches.

    .PARAMETER InputObject
        The array of release objects (output of Get-GitHubReleases).

    .PARAMETER VersionPattern
        Optional. Regex pattern with a capture group to extract the version from tag_name. If not provided, tag_name is used as-is.

    .PARAMETER VersionFormatScriptBlock
        Optional. Script block to construct the version string from $Matches after a successful pattern match.

    .PARAMETER MinimumVersion
        Optional. Only releases with version greater than or equal to this value are included. Uses [version] comparison.

    .EXAMPLE
        $expanded = Get-GitHubReleases ... | Expand-GitHubReleases -VersionPattern 'T(\d+)_(\d+)_(\d+)' -VersionFormatScriptBlock { "$($Matches[1]).$($Matches[2]).$($Matches[3])" } -MinimumVersion '4.0.0'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,
        [string]$VersionPattern,
        [scriptblock]$VersionFormatScriptBlock,
        [string]$MinimumVersion
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
