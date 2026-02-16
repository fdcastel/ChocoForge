function Resolve-SourcePublishingStatus {
    <#
    .SYNOPSIS
        Resolves the publishing status and API key for a package source.

    .DESCRIPTION
        Evaluates the API key configuration for a source and determines if it can be used
        for publishing. Sets resolvedApiKey, skipReason, and warningMessage properties
        on the source object.

    .PARAMETER Source
        The source configuration object to evaluate and update.

    .PARAMETER SourceName
        The name of the source (for log messages).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Source,

        [Parameter(Mandatory)]
        [string]$SourceName
    )

    $resolvedApiKey = $null
    $skipReason = $null
    $warningMessage = $null

    if ($Source.apiKey) {
        $resolvedApiKey = Expand-EnvironmentVariables $Source.apiKey
        if (-not $resolvedApiKey) {
            Write-VerboseMark "Source '$SourceName' environment variable $($Source.apiKey) is not set. Skipping publishing."
            $skipReason = "Environment variable $($Source.apiKey) not set."
        } elseif ($resolvedApiKey -eq $Source.apiKey) {
            Write-VerboseMark "Source '$SourceName' has an API key stored in plain text in the configuration file (not recommended). Please consider using an environment variable instead."
            $warningMessage = 'API key stored in plain text in the configuration file (not recommended).'
        }
    } else {
        Write-VerboseMark "Source '$SourceName' does not have an API key configured. Skipping publishing."
        $skipReason = 'No API key in the configuration file'
    }

    $Source | Add-Member -MemberType NoteProperty -Name 'resolvedApiKey' -Value $resolvedApiKey -Force
    $Source | Add-Member -MemberType NoteProperty -Name 'skipReason' -Value $skipReason -Force
    $Source | Add-Member -MemberType NoteProperty -Name 'warningMessage' -Value $warningMessage -Force
}
