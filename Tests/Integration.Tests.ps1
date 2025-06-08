Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Integration' {
    InModuleScope 'ChocoForge' {
        BeforeDiscovery {
            $missingApiKey = -not $env:GITHUB_API_KEY
            if ($missingApiKey) {
                Write-Warning 'GITHUB_API_KEY environment variable is not set. Some tests will be skipped.'
            }
        }

        It 'Fetch, build and publish' -Skip:$missingApiKey {
            $configPath = "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $versionsToTest = @('5.0.1', '3.0.10')

            $nuspecPath = "$PSScriptRoot/assets/firebird-package/firebird.nuspec"
            $target = $config.targets.github

            $packagesPushed = $config.versions |
                Where-Object { $_.version -in $versionsToTest } |
                    Build-ChocolateyPackage -NuspecPath $nuspecPath |
                        Publish-ChocolateyPackage -TargetUrl $target.url -ApiKey $env:GITHUB_API_KEY -Force

            @($packagesPushed).Count | Should -Be 2
        }
    }
}
