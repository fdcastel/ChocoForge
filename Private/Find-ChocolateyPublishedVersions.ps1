function Find-ChocolateyPublishedVersions {
    <#
    .SYNOPSIS
        Returns all published versions of a given package from a Chocolatey repository.

    .DESCRIPTION
        Uses the choco.exe CLI to search for all versions of a package in a Chocolatey-compatible repository. Returns a list of version objects only.

    .PARAMETER PackageName
        The name of the package to search for.

    .PARAMETER SourceUrl
        The Chocolatey repository URL. If not specified, uses the default community repository.

    .EXAMPLE
        Find-ChocolateyPublishedVersions -PackageName 'git'
    .EXAMPLE
        Find-ChocolateyPublishedVersions -PackageName 'git' -SourceUrl 'https://myrepo/chocolatey/'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PackageName,
        [string]$SourceUrl
    )

    $defaultSource = 'https://community.chocolatey.org/api/v2/'
    $src = if ($SourceUrl) { $SourceUrl } else { $defaultSource }

    $args = @(
        'search', $PackageName, '--all', '--exact', '--source', $src,
        '--limit-output', '--skip-compatibility-checks', '--ignore-http-cache'
    )

    $result = Invoke-Chocolatey -Arguments $args
    if ($result.ExitCode -ne 0) {
        throw "choco search failed: $($result.StdErr)"
    }

    # Parse output: lines like 'git|2.44.0'
    $lines = $result.StdOut -split "`n" | Where-Object { $_ -match '\|' }
    $versions = foreach ($line in $lines) {
        $parts = $line -split '\|'
        [version]$parts[1].Trim()
    }
    return $versions
}
