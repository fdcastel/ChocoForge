Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Integration' {
    InModuleScope 'ChocoForge' {
        BeforeDiscovery {
            $missingApiKey = -not $env:APIKEY_GITHUB
            if ($missingApiKey) {
                Write-Warning 'APIKEY_GITHUB environment variable is not set. Some tests will be skipped.'
            }
        }

        It 'Fetch, build and publish' -Skip:$missingApiKey {
            $configPath = "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $versionsToTest = @('5.0.1', '3.0.10')

            $nuspecPath = "$PSScriptRoot/assets/firebird-package/firebird.nuspec"
            $source = $config.sources.github

            $packagesPushed = $config.versions |
                Where-Object { $_.version -in $versionsToTest } |
                    Build-ChocolateyPackage -NuspecPath $nuspecPath |
                        Publish-ChocolateyPackage -SourceUrl $source.url -ApiKey $env:APIKEY_GITHUB -Force

            $packagesPushed | Should -HaveCount 2
        }
    }
}
