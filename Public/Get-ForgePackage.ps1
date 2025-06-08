function Get-ForgePackage {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path,

        [Parameter()]
        [switch]$Passthru
    )
    
    $config = Read-ForgeConfiguration -Path $Path | Resolve-ForgeConfiguration
    $config | ConvertTo-Json -Depth 20 | Out-File 'C:/temp/configuration.json'

    if ($Passthru.IsPresent) {
        Write-VerboseMark 'Returning configuration info as object (Passthru).'
        return $config
    } else {
        $config | Write-ForgeConfiguration
    }
}
