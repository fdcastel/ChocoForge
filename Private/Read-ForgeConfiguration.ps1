function Read-ForgeConfiguration {
    <#
    .SYNOPSIS
        Reads, parses, and validates a ChocoForge YAML configuration file.

    .DESCRIPTION
        Loads a ChocoForge YAML configuration file, parses it, and validates that all required fields and structure are present. 
        
        If no path is provided, the function will search for a single .forge.yaml file in the current directory. 
        
        Returns the parsed configuration as a PowerShell custom object.

        Required fields include:
        - 'package'
        - 'releases.source' (must be a GitHub URL)
        - At least one 'releases.flavors' entry (each must have 'versionPattern' and 'assetsPattern')
        - At least one 'targets' entry (each must have 'url' and 'apiKey')

    .PARAMETER Path
        Path to the YAML configuration file. If not provided, the function will search for a single .forge.yaml file in the current directory.

    .EXAMPLE
        Read-ForgeConfiguration -Path 'Samples/firebird.forge.yaml'
        
        Loads and validates the specified configuration file.

    .EXAMPLE
        Read-ForgeConfiguration
        
        Auto-discovers and loads a .forge.yaml file in the current directory if only one exists.

    .OUTPUTS
        PSCustomObject
        The parsed and validated configuration object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not $Path) {
        Write-VerboseMark 'No path provided. Searching for .forge.yaml files in current directory.'
        $forgeFiles = Get-ChildItem -Path (Get-Location) -Filter '*.forge.yaml' | Select-Object -ExpandProperty FullName
        if ($forgeFiles.Count -eq 0) {
            throw 'No .forge.yaml file found in the current directory.'
        } elseif ($forgeFiles.Count -gt 1) {
            throw 'Multiple .forge.yaml files found in the current directory. Please specify one.'
        }
        $Path = $forgeFiles[0]
    }

    if (-not (Test-Path $Path)) {
        throw "YAML configuration file not found: $Path"
    }

    Write-VerboseMark "Using configuration file: $($Path)"
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
