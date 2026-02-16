function Compare-PublishedVersions {
    <#
    .SYNOPSIS
        Finds versions that are missing from the published versions list.

    .DESCRIPTION
        Compares a list of release versions against a list of published versions to find
        which releases are not yet published. When comparing, treats Revision=-1 as a
        wildcard that matches any Revision value.

    .PARAMETER ReleaseVersions
        Array of version objects from resolved releases.

    .PARAMETER PublishedVersions
        Array of version objects already published to a source.

    .OUTPUTS
        System.Version[]
        Array of versions that are in ReleaseVersions but not in PublishedVersions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [version[]]$ReleaseVersions,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [version[]]$PublishedVersions
    )

    $ReleaseVersions | Where-Object {
        $releaseVersion = [version]$_
        $isPublished = $false

        foreach ($pubVersion in $PublishedVersions) {
            # Compare Major, Minor, Build
            if ($pubVersion.Major -eq $releaseVersion.Major -and
                $pubVersion.Minor -eq $releaseVersion.Minor -and
                $pubVersion.Build -eq $releaseVersion.Build) {

                # If either has Revision=-1, treat it as a wildcard match
                if ($pubVersion.Revision -eq -1 -or $releaseVersion.Revision -eq -1) {
                    $isPublished = $true
                    break
                }

                # Both have explicit Revision values, must match exactly
                if ($pubVersion.Revision -eq $releaseVersion.Revision) {
                    $isPublished = $true
                    break
                }
            }
        }

        -not $isPublished
    }
}
