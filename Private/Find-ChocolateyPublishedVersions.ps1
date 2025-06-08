function Find-ChocolateyPublishedVersions {
    <#
    .SYNOPSIS
        Returns all published versions of a given package from a Chocolatey repository.

    .DESCRIPTION
        Uses the choco.exe CLI to search for all versions of a package in a Chocolatey-compatible repository. Supports authentication via User and Password parameters. Defaults to the community repository if SourceUrl is not specified. Returns a list of [version] objects. Throws on errors.

    .PARAMETER PackageName
        The name of the package to search for.

    .PARAMETER SourceUrl
        The Chocolatey repository URL. If not specified, uses the default community repository (https://community.chocolatey.org/api/v2).

    .PARAMETER User
        (Optional) The username for authenticating with the repository, if required.

    .PARAMETER Password
        (Optional) The password or API key for authenticating with the repository, if required.

    .EXAMPLE
        Find-ChocolateyPublishedVersions -PackageName 'git'
    .EXAMPLE
        Find-ChocolateyPublishedVersions -PackageName 'git' -SourceUrl 'https://myrepo/chocolatey/'
    .EXAMPLE
        Find-ChocolateyPublishedVersions -PackageName 'git' -SourceUrl 'https://myrepo/chocolatey/' -User 'myuser' -Password 'mypassword'

    .NOTES
        - Returns a list of [version] objects.
        - Throws on errors.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PackageName,
        [string]$SourceUrl,
        [string]$User,
        [string]$Password
    )

    $SourceUrl = $SourceUrl ? $SourceUrl : 'https://community.chocolatey.org/api/v2'

    $chocoArguments = @(
        'search', $PackageName, '--all', '--exact', '--source', $SourceUrl,
        '--skip-compatibility-checks', '--ignore-http-cache', '--limit-output' 
    )
    if ($User -and $Password) {
        $chocoArguments += @('--user', $User, '--password', $Password)
    }

    $result = Invoke-Chocolatey -Arguments $chocoArguments
    if ($result.ExitCode -ne 0) {
        throw "choco search failed: $($result.StdOut)"
    }

    # Parse output: lines like 'git|2.44.0'
    $lines = $result.StdOut -split "`n" | Where-Object { $_ -match '\|' }
    $versions = foreach ($line in $lines) {
        $parts = $line -split '\|'
        [version]$parts[1].Trim()
    }
    return $versions
}
