function Get-ForgePackage {
    <#
    .SYNOPSIS
        Reads, resolves, and outputs a ChocoForge YAML configuration as JSON or as an object.

    .DESCRIPTION
        Loads and resolves a ChocoForge YAML configuration file using Read-ForgeConfiguration and Resolve-ForgeConfiguration. 
        
        By default, writes the configuration using Write-ForgeConfiguration. 
        
        If -Passthru is specified, returns the configuration object instead. 

    .PARAMETER Path
        Path to the YAML configuration file. If not provided, auto-discovery is handled by Read-ForgeConfiguration.

    .PARAMETER Passthru
        If specified, returns the resolved configuration object instead of writing it.

    .EXAMPLE
        Get-ForgePackage -Path 'Samples/firebird.forge.yaml'

    .EXAMPLE
        Get-ForgePackage -Path 'Samples/firebird.forge.yaml' -Passthru
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path,

        [Parameter()]
        [switch]$Passthru
    )
    
    $config = Read-ForgeConfiguration -Path $Path | Resolve-ForgeConfiguration

    if ($Passthru.IsPresent) {
        Write-VerboseMark 'Returning configuration info as object (Passthru).'
        return $config
    } else {
        $config | Write-ForgeConfiguration
    }
}
