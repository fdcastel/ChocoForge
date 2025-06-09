function Find-ChocolateyPublishedVersions {
    <#
    .SYNOPSIS
        Lists all published versions of a Chocolatey package from a specified repository.

    .DESCRIPTION
        Retrieves all available versions of a given package from a Chocolatey-compatible repository using the choco CLI.

        Supports authentication if required. If no repository URL is specified, the default Chocolatey community repository is used. 

        Returns a list of version objects.

    .PARAMETER PackageName
        The name of the Chocolatey package to search for.

    .PARAMETER SourceUrl
        Optional. The URL of the Chocolatey repository. Defaults to the community repository (https://community.chocolatey.org/api/v2) if not specified.

    .PARAMETER User
        Optional. The username for authenticating with the repository, if required.

    .PARAMETER Password
        Optional. The password or API key for authenticating with the repository, if required.

    .EXAMPLE
        Find-ChocolateyPublishedVersions -PackageName 'git'
        
        Lists all published versions of the 'git' package from the default Chocolatey repository.

    .EXAMPLE
        Find-ChocolateyPublishedVersions -PackageName 'git' -SourceUrl 'https://myrepo/chocolatey/'
        
        Lists all published versions of the 'git' package from a custom repository.

    .EXAMPLE
        Find-ChocolateyPublishedVersions -PackageName 'git' -SourceUrl 'https://myrepo/chocolatey/' -User 'myuser' -Password 'mypassword'
        
        Lists all published versions of the 'git' package from a custom repository using authentication.

    .OUTPUTS
        System.Version[]
        A list of version objects representing all published versions of the package.
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
        'search', $PackageName, '--all', '--exact', '--source', $SourceUrl, '--ignore-http-cache', '--limit-output'
    )
    if ($User -and $Password) {
        $chocoArguments += @('--user', $User, '--password', $Password)
    }

    Write-VerboseMark -Message "Searching for published versions of package '$PackageName' in source '$SourceUrl'."
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
