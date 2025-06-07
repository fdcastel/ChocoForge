function Read-ForgeConfiguration {
    <#
    .SYNOPSIS
        Reads and validates a ChocoForge YAML configuration file.

    .DESCRIPTION
        Loads a YAML file (see Samples/firebird.forge.yaml for structure), parses it, and validates required fields and structure. Throws on validation errors. Returns the parsed configuration object.

    .PARAMETER Path
        Path to the YAML configuration file.

    .EXAMPLE
        Read-ForgeConfiguration -Path 'Samples/firebird.forge.yaml'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "YAML configuration file not found: $Path"
    }

    Write-VerboseMark -Message "Reading YAML configuration from '$Path'"
    $config = ConvertFrom-Yaml (Get-Content -Raw -LiteralPath $Path)

    # Validate 'package'
    if (-not $config.package) {
        throw "Missing required 'package' property in YAML configuration."
    }

    # Validate 'releases.source' (must be a GitHub URL)
    if (-not $config.releases -or -not $config.releases.source) {
        throw "Missing required 'releases.source' property."
    }
    if ($config.releases.source -notmatch '^https://github.com/.+') {
        throw "'releases.source' must be a GitHub repository URL."
    }

    # Validate 'releases.flavors' (at least one flavor, each with versionPattern and assetsPattern)
    if (-not $config.releases.flavors -or $config.releases.flavors.Count -eq 0) {
        throw "At least one 'releases.flavors' entry is required."
    }
    foreach ($flavorName in $config.releases.flavors.Keys) {
        $flavor = $config.releases.flavors[$flavorName]
        $patterns = @{}
        foreach ($item in $flavor) {
            if ($item.versionPattern) { $patterns.versionPattern = $item.versionPattern }
            if ($item.assetsPattern) { $patterns.assetsPattern = $item.assetsPattern }
        }
        if (-not $patterns.versionPattern) {
            throw "Flavor '$flavorName' is missing 'versionPattern'."
        }
        if (-not $patterns.assetsPattern) {
            throw "Flavor '$flavorName' is missing 'assetsPattern'."
        }
    }

    # Validate 'targets' (at least one, each with url and apiKey)
    if (-not $config.targets -or $config.targets.Count -eq 0) {
        throw "At least one 'targets' entry is required."
    }
    foreach ($targetName in $config.targets.Keys) {
        $target = $config.targets[$targetName]
        if (-not $target.url) {
            throw "Target '$targetName' is missing 'url'."
        }
        if (-not $target.apiKey) {
            throw "Target '$targetName' is missing 'apiKey'."
        }
    }

    Write-VerboseMark -Message 'YAML configuration validated successfully.'
    return $config
}
