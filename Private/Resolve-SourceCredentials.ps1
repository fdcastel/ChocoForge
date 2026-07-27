function Resolve-SourceCredentials {
    <#
    .SYNOPSIS
        Resolves authentication credentials for a package source based on its URL type.

    .DESCRIPTION
        Determines the source type (GitHub, GitLab, or other) from the URL and constructs
        the appropriate authentication parameters. GitHub uses the owner from the URL as username.
        GitLab requires a username in the source configuration.

        When the API key environment variable is not set, an empty hashtable is returned rather
        than throwing, so that a configuration can still be inspected with only some tokens present.
        A GitLab source with no configured username does throw, because that is a configuration error.

    .PARAMETER Source
        The source configuration object containing url, apiKey, and optionally username.

    .PARAMETER SourceName
        The name of the source (for error messages).

    .OUTPUTS
        System.Collections.Hashtable
        A hashtable with User and Password keys if authentication is needed, or empty hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Source,

        [Parameter(Mandatory)]
        [string]$SourceName
    )

    $credentials = @{}

    if ($Source.url.StartsWith('https://nuget.pkg.github.com')) {
        # GitHub: username is the owner from the URL
        $userName = ($Source.url -replace '^https://nuget.pkg.github.com/', '') -replace '/.*', ''
        $password = Expand-EnvironmentVariables $Source.apiKey
        if (-not $password) {
            # A missing token is not fatal: the caller reports the source as unqueryable so that
            # the other sources can still be inspected. Resolve-SourcePublishingStatus records why.
            Write-VerboseMark "GitHub source '$SourceName' has no usable API key. Returning empty credentials."
            return $credentials
        }
        $credentials['User'] = $userName
        $credentials['Password'] = $password
        Write-VerboseMark "Resolved GitHub credentials for source '$SourceName' (user: $userName)."
    } elseif ($Source.url.StartsWith('https://gitlab.com')) {
        # GitLab: username must be in the configuration. Unlike a missing token, this is a
        # configuration error the user must fix, so it still throws.
        $userName = $Source.username
        if (-not $userName) {
            throw "GitLab source '$SourceName' requires a username to be set in the configuration."
        }
        $password = Expand-EnvironmentVariables $Source.apiKey
        if (-not $password) {
            Write-VerboseMark "GitLab source '$SourceName' has no usable API key. Returning empty credentials."
            return $credentials
        }
        $credentials['User'] = $userName
        $credentials['Password'] = $password
        Write-VerboseMark "Resolved GitLab credentials for source '$SourceName' (user: $userName)."
    } else {
        Write-VerboseMark "Source '$SourceName' does not require special credentials."
    }

    return $credentials
}
