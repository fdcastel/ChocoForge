function Get-ChocolateyPackages {
    <#
    .SYNOPSIS
        Queries all versions of a given package from a Chocolatey repository using 'choco search'.

    .DESCRIPTION
        Uses the choco.exe CLI to search for all versions of a package in a Chocolatey-compatible repository. Returns a list of versions and metadata for the package.

    .PARAMETER PackageName
        The name of the package to search for.

    .PARAMETER SourceUrl
        The Chocolatey repository URL. If not specified, uses the default community repository.

    .EXAMPLE
        Get-ChocolateyPackages -PackageName 'git'
    .EXAMPLE
        Get-ChocolateyPackages -PackageName 'git' -SourceUrl 'https://myrepo/chocolatey/'
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
    $packages = foreach ($line in $lines) {
        $parts = $line -split '\|'
        [PSCustomObject]@{
            Name    = $parts[0].Trim()
            Version = [version]$parts[1].Trim()
        }
    }
    $packages
}
