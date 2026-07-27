function Resolve-ForgeNuspecPath {
    <#
    .SYNOPSIS
        Derives the .nuspec path that accompanies a .forge.yaml configuration file.

    .DESCRIPTION
        A ChocoForge package keeps its .nuspec beside its .forge.yaml, sharing the same base name.
        This function maps one to the other.

    .PARAMETER ConfigurationPath
        Full path to the .forge.yaml file, as reported by Read-ForgeConfiguration's 'configurationPath' property.

    .EXAMPLE
        Resolve-ForgeNuspecPath -ConfigurationPath 'C:/packages/firebird/firebird.forge.yaml'

        Returns 'C:/packages/firebird/firebird.nuspec'.

    .OUTPUTS
        System.String. The path to the sibling .nuspec file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationPath
    )

    # The dots are escaped: an unescaped '.forge.yaml$' also matches names like 'appXforgeYyaml'.
    $nuspecPath = $ConfigurationPath -replace '\.forge\.yaml$', '.nuspec'

    if ($nuspecPath -eq $ConfigurationPath) {
        throw "Cannot derive a .nuspec path from '$ConfigurationPath': expected a file named '*.forge.yaml'."
    }

    Write-VerboseMark "Nuspec path resolved: $($nuspecPath)"
    return $nuspecPath
}
