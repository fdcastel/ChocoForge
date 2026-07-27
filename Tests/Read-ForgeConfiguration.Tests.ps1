Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Read-ForgeConfiguration' {
    InModuleScope 'ChocoForge' {
        BeforeAll {
            $script:tempDir = Join-Path $env:TEMP 'chocoforge-test-config'
            if (Test-Path $script:tempDir) { Remove-Item -Recurse -Force $script:tempDir }
            New-Item -ItemType Directory -Path $script:tempDir | Out-Null
        }

        AfterAll {
            if (Test-Path $script:tempDir) { Remove-Item -Recurse -Force $script:tempDir }
        }

        It 'Loads and validates the firebird sample configuration' {
            $configPath = "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath

            $config | Should -Not -BeNullOrEmpty
            $config.package | Should -Be 'firebird'
            $config.releases.source | Should -Match '^https://github.com/'
            $config.releases.flavors.Keys | Should -Contain 'current'
            $config.sources.Keys | Should -Not -BeNullOrEmpty
        }

        It 'Loads and validates the qemu-img sample configuration' {
            $configPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath

            $config | Should -Not -BeNullOrEmpty
            $config.package | Should -Be 'qemu-img'
        }

        It 'Throws on non-existent file' {
            { Read-ForgeConfiguration -Path 'nonexistent.forge.yaml' } | Should -Throw '*not found*'
        }

        It 'Throws on missing package property' {
            $yaml = @'
releases:
  source: https://github.com/owner/repo
  flavors:
    current:
      - versionPattern: 'v(\d+\.\d+\.\d+)$'
      - assetsPattern: '\.zip$'
sources:
  github:
    url: https://nuget.pkg.github.com/owner/index.json
    apiKey: ${APIKEY}
'@
            $path = Join-Path $script:tempDir 'no-package.forge.yaml'
            Set-Content -Path $path -Value $yaml
            { Read-ForgeConfiguration -Path $path } | Should -Throw "*Missing required 'package'*"
        }

        It 'Throws on missing releases.source' {
            $yaml = @'
package: test
releases:
  flavors:
    current:
      - versionPattern: 'v(\d+\.\d+\.\d+)$'
      - assetsPattern: '\.zip$'
sources:
  github:
    url: https://nuget.pkg.github.com/owner/index.json
    apiKey: ${APIKEY}
'@
            $path = Join-Path $script:tempDir 'no-source.forge.yaml'
            Set-Content -Path $path -Value $yaml
            { Read-ForgeConfiguration -Path $path } | Should -Throw "*Missing required 'releases.source'*"
        }

        It 'Throws on non-GitHub releases.source URL' {
            $yaml = @'
package: test
releases:
  source: https://gitlab.com/owner/repo
  flavors:
    current:
      - versionPattern: 'v(\d+\.\d+\.\d+)$'
      - assetsPattern: '\.zip$'
sources:
  github:
    url: https://nuget.pkg.github.com/owner/index.json
    apiKey: ${APIKEY}
'@
            $path = Join-Path $script:tempDir 'bad-source.forge.yaml'
            Set-Content -Path $path -Value $yaml
            { Read-ForgeConfiguration -Path $path } | Should -Throw "*must be a GitHub repository URL*"
        }

        It 'Throws on missing versionPattern in flavor' {
            $yaml = @'
package: test
releases:
  source: https://github.com/owner/repo
  flavors:
    current:
      - assetsPattern: '\.zip$'
sources:
  github:
    url: https://nuget.pkg.github.com/owner/index.json
    apiKey: ${APIKEY}
'@
            $path = Join-Path $script:tempDir 'no-version-pattern.forge.yaml'
            Set-Content -Path $path -Value $yaml
            { Read-ForgeConfiguration -Path $path } | Should -Throw "*missing 'versionPattern'*"
        }

        It 'Throws on missing assetsPattern in flavor' {
            $yaml = @'
package: test
releases:
  source: https://github.com/owner/repo
  flavors:
    current:
      - versionPattern: 'v(\d+\.\d+\.\d+)$'
sources:
  github:
    url: https://nuget.pkg.github.com/owner/index.json
    apiKey: ${APIKEY}
'@
            $path = Join-Path $script:tempDir 'no-assets-pattern.forge.yaml'
            Set-Content -Path $path -Value $yaml
            { Read-ForgeConfiguration -Path $path } | Should -Throw "*missing 'assetsPattern'*"
        }

        It 'Throws on missing sources' {
            $yaml = @'
package: test
releases:
  source: https://github.com/owner/repo
  flavors:
    current:
      - versionPattern: 'v(\d+\.\d+\.\d+)$'
      - assetsPattern: '\.zip$'
'@
            $path = Join-Path $script:tempDir 'no-sources.forge.yaml'
            Set-Content -Path $path -Value $yaml
            { Read-ForgeConfiguration -Path $path } | Should -Throw "*At least one 'sources' entry*"
        }

        It 'Throws on source missing url' {
            $yaml = @'
package: test
releases:
  source: https://github.com/owner/repo
  flavors:
    current:
      - versionPattern: 'v(\d+\.\d+\.\d+)$'
      - assetsPattern: '\.zip$'
sources:
  github:
    apiKey: ${APIKEY}
'@
            $path = Join-Path $script:tempDir 'no-source-url.forge.yaml'
            Set-Content -Path $path -Value $yaml
            { Read-ForgeConfiguration -Path $path } | Should -Throw "*missing 'url'*"
        }

        It 'Throws on source missing apiKey' {
            $yaml = @'
package: test
releases:
  source: https://github.com/owner/repo
  flavors:
    current:
      - versionPattern: 'v(\d+\.\d+\.\d+)$'
      - assetsPattern: '\.zip$'
sources:
  github:
    url: https://nuget.pkg.github.com/owner/index.json
'@
            $path = Join-Path $script:tempDir 'no-apikey.forge.yaml'
            Set-Content -Path $path -Value $yaml
            { Read-ForgeConfiguration -Path $path } | Should -Throw "*missing 'apiKey'*"
        }

        It 'Loads v2 format (plain object flavors) correctly' {
            $configPath = "$PSScriptRoot/assets/v2-format-package/test-v2.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath

            $config | Should -Not -BeNullOrEmpty
            $config.package | Should -Be 'test-v2'
            $config.releases.flavors.current.versionPattern | Should -Be 'v(\d+\.\d+\.\d+)$'
            $config.releases.flavors.current.assetsPattern | Should -Be '\.zip$'
            $config.releases.flavors.current.minimumVersion | Should -Be '9.0.0'
        }

        It 'Normalizes v1 format (array-of-dicts) to flat dictionary' {
            $yaml = @'
package: test
releases:
  source: https://github.com/owner/repo
  flavors:
    current:
      - versionPattern: 'v(\d+\.\d+\.\d+)$'
      - assetsPattern: '\.zip$'
      - minimumVersion: 1.0.0
sources:
  github:
    url: https://nuget.pkg.github.com/owner/index.json
    apiKey: ${APIKEY}
'@
            $path = Join-Path $script:tempDir 'v1-format.forge.yaml'
            Set-Content -Path $path -Value $yaml
            $config = Read-ForgeConfiguration -Path $path

            # After normalization, flavor should be a dictionary, not an array
            $flavor = $config.releases.flavors.current
            $flavor | Should -Not -BeOfType [System.Collections.IList]
            $flavor.versionPattern | Should -Be 'v(\d+\.\d+\.\d+)$'
            $flavor.assetsPattern | Should -Be '\.zip$'
            $flavor.minimumVersion | Should -Be '1.0.0'
        }

        It 'Auto-discovers a single .forge.yaml when given a directory' {
            $dir = Join-Path $script:tempDir 'discovery-one'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Copy-Item "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml" (Join-Path $dir 'only.forge.yaml')

            $config = Read-ForgeConfiguration -Path $dir
            $config.package | Should -Be 'qemu-img'
        }

        It 'Exposes the resolved file path as configurationPath' {
            $dir = Join-Path $script:tempDir 'discovery-path'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Copy-Item "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml" (Join-Path $dir 'only.forge.yaml')

            $config = Read-ForgeConfiguration -Path $dir
            $config.configurationPath | Should -Match 'only\.forge\.yaml$'
            Test-Path $config.configurationPath | Should -BeTrue
        }

        It 'Sets configurationPath even when an explicit file is given' {
            $configPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath
            $config.configurationPath | Should -Match 'qemu-img\.forge\.yaml$'
        }

        It 'Treats an empty -Path as the current directory' {
            $dir = Join-Path $script:tempDir 'discovery-empty-path'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Copy-Item "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml" (Join-Path $dir 'only.forge.yaml')

            Push-Location $dir
            try {
                $config = Read-ForgeConfiguration -Path ''
                $config.package | Should -Be 'qemu-img'
            } finally {
                Pop-Location
            }
        }

        It 'Throws a helpful error when no .forge.yaml exists in the directory' {
            $dir = Join-Path $script:tempDir 'discovery-none'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null

            { Read-ForgeConfiguration -Path $dir } | Should -Throw '*No .forge.yaml file found*'
        }

        It 'Throws and names the candidates when several .forge.yaml files exist' {
            $dir = Join-Path $script:tempDir 'discovery-many'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Copy-Item "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml" (Join-Path $dir 'alpha.forge.yaml')
            Copy-Item "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml" (Join-Path $dir 'beta.forge.yaml')

            { Read-ForgeConfiguration -Path $dir } | Should -Throw '*alpha.forge.yaml*'
        }

        It 'Validates v2 format missing versionPattern' {
            $yaml = @'
package: test
releases:
  source: https://github.com/owner/repo
  flavors:
    current:
      assetsPattern: '\.zip$'
sources:
  github:
    url: https://nuget.pkg.github.com/owner/index.json
    apiKey: ${APIKEY}
'@
            $path = Join-Path $script:tempDir 'v2-no-version-pattern.forge.yaml'
            Set-Content -Path $path -Value $yaml
            { Read-ForgeConfiguration -Path $path } | Should -Throw "*missing 'versionPattern'*"
        }
    }
}
