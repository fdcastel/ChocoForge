# ChocoForge

<img src="docs/ChocoForge-Logo.png" alt="ChocoForge Logo" width="180" align="right" />

PowerShell toolkit for automating the creation, management, and publishing of Chocolatey packages. 

It is designed to simplify the process of keeping Chocolatey repositories up-to-date with the latest releases from upstream projects, supporting advanced templating, flexible configuration, and multi-source publishing.

## Features

- **Declarative YAML Configuration**: Define your package, release sources, flavors, and publishing sources in a single `.forge.yaml` file.
- **GitHub Releases Integration**: Automatically fetches and processes releases and assets from GitHub repositories.
- **Template-Based Packaging**: Uses template substitution to generate nuspec files and scripts from your configuration and release data.
- **Multi-Architecture & Flavors Support**: Maintain packages for multiple architectures or release flavors (e.g. `current`, `beta`) from a single configuration.
- **Multi-source Publishing**: Publish packages to multiple sources, including the official Chocolatey community feed, GitHub NuGet registry, GitLab package registry and any other custom Nuget-compatible repository.
- **SHA256 Handling**: Automatically calculates SHA256 checksums for assets, or uses pre-calculated SHA256 values from GitHub releases (when available).
- **Output Formatting**: Consistent, readable output for status, errors, and results, designed for both human and script consumption.

## Example output

<img src="docs/Example.png" alt="ChocoForge Example Workflow" width="600" />

## Requirements

- PowerShell 7.4 or later
- Chocolatey CLI (`choco.exe`) installed and available in your PATH
- PowerShell-YAML module (installed automatically as a dependency)

## Installation

```powershell
Install-Module ChocoForge -Scope CurrentUser
```

## Quick Start

1. **Create a `.forge.yaml` configuration file**
2. **Create a `.nuspec` template file** (with placeholders like `{{version}}`, `{{assets.x64.browser_download_url}}`)
3. **Create installation scripts** in a `tools/` folder (with template placeholders)
4. **Review the configuration** and publishing status:
   ```powershell
   Get-ForgePackage
   ```
5. **Build and publish** missing packages to all configured sources:
   ```powershell
   Sync-ForgePackage -Verbose
   ```

---

## Configuration Reference

The `.forge.yaml` file defines all aspects of your package automation. Below is a complete reference of all available configuration options.

### Basic Structure

```yaml
package: your-package-name

releases:
  source: https://github.com/owner/repo
  flavors:
    flavor-name:
      - versionPattern: 'regex-pattern'
      - assetsPattern: 'regex-pattern'
      - minimumVersion: 1.0.0  # optional

sources:
  source-name:
    url: https://nuget-source-url
    apiKey: ${ENV_VAR_NAME}
```

### `package`

**Required.** The Chocolatey package identifier.

```yaml
package: firebird
```

This must match the `<id>` in your `.nuspec` file.

### `releases`

**Required.** Configuration for fetching release information from upstream sources.

#### `releases.source`

**Required.** The GitHub repository URL to fetch releases from.

```yaml
releases:
  source: https://github.com/FirebirdSQL/firebird
```

**Note:** Currently, only GitHub repositories are supported as release sources.

#### `releases.flavors`

**Required.** At least one flavor must be defined. Flavors allow you to track different release channels (e.g., stable, beta) or different version branches (e.g., v3, v4, v5) from the same repository.

Each flavor consists of:

##### `versionPattern`

**Required.** A regular expression pattern to extract the version from the GitHub release tag name. The first capture group must contain the semantic version.

```yaml
flavors:
  current:
    - versionPattern: 'v(5\.\d+\.\d+)$'
```

**Example tag matching:**
- Tag `v5.0.1` → Version `5.0.1`
- Tag `v5.0.1-beta` → Not matched (pattern requires tag to end with the version)

##### `assetsPattern`

**Required.** A regular expression pattern to filter and match release assets. Only assets matching this pattern will be processed.

```yaml
flavors:
  current:
    - assetsPattern: 'Firebird-[\d.]+-\d+-windows-(?<arch>[^-_.]+)\.exe$'
```

**Named Capture Groups:** You can use named capture groups (e.g., `(?<arch>...)`) to extract properties from asset filenames. These become available as template variables.

**Example with multiple architectures:**
```yaml
assetsPattern: 'myapp-(?<arch>x64|x86)\.zip$'
```

This pattern would match:
- `myapp-x64.zip` → `arch = "x64"`
- `myapp-x86.zip` → `arch = "x86"`

**Transposition:** When a named capture group is used (like `arch`), ChocoForge automatically transposes the assets array into a hashtable keyed by that property:

```
assets: {
  x64: { name: "myapp-x64.zip", browser_download_url: "...", ... },
  x86: { name: "myapp-x86.zip", browser_download_url: "...", ... }
}
```

This makes it easy to reference architecture-specific URLs in templates:
```
$url64 = '{{assets.x64.browser_download_url}}'
$url32 = '{{assets.x86.browser_download_url}}'
```

##### `minimumVersion`

**Optional.** The minimum version to consider for updates. Older versions will be ignored.

```yaml
flavors:
  v3:
    - versionPattern: 'v(3\.\d+\.\d+)$'
    - assetsPattern: 'Firebird-\d+\.\d+\.\d+\.\d+[-_]\d+[-_](?<arch>[^-_.]+)\.exe$'
    - minimumVersion: 3.0.10
```

This is useful for:
- Skipping very old releases that may have issues
- Starting package maintenance from a known-good version
- Avoiding republishing old versions unnecessarily

**Example:** Multiple flavors for different major versions:

```yaml
releases:
  source: https://github.com/FirebirdSQL/firebird
  flavors:
    current:
      - versionPattern: 'v(5\.\d+\.\d+)$'
      - assetsPattern: 'Firebird-[\d.]+-\d+-windows-(?<arch>[^-_.]+)\.exe$'
    v4:
      - versionPattern: 'v(4\.\d+\.\d+)$'
      - assetsPattern: 'Firebird-\d+\.\d+\.\d+\.\d+[-_]\d+[-_](?<arch>[^-_.]+)\.exe$'
    v3:
      - versionPattern: 'v(3\.\d+\.\d+)$'
      - assetsPattern: 'Firebird-\d+\.\d+\.\d+\.\d+[-_]\d+[-_](?<arch>[^-_.]+)\.exe$'
      - minimumVersion: 3.0.10
```

### `sources`

**Required.** At least one publishing source must be defined. Sources are NuGet-compatible package repositories where packages will be published.

Each source consists of:

#### `url`

**Required.** The NuGet feed URL.

```yaml
sources:
  community:
    url: https://community.chocolatey.org/api/v2
```

**Supported sources:**
- **Chocolatey Community Repository**: `https://community.chocolatey.org/api/v2`
- **GitHub Packages**: `https://nuget.pkg.github.com/owner/index.json`
- **GitLab Package Registry**: `https://gitlab.com/api/v4/projects/PROJECT_ID/packages/nuget/index.json`
- **Any NuGet-compatible repository**

#### `apiKey`

**Required.** The API key for publishing packages.

**Best Practice:** Use environment variable references instead of hardcoding keys:

```yaml
sources:
  community:
    url: https://community.chocolatey.org/api/v2
    apiKey: ${CHOCOLATEY_API_KEY}
```

ChocoForge will resolve `${ENV_VAR_NAME}` patterns by reading from environment variables.

**Security Warning:** If you provide a plain text API key instead of an environment variable reference, ChocoForge will display a warning. Environment variable references are strongly recommended.

#### `username` (GitLab only)

**Required for GitLab sources.** The username for authenticating to GitLab.

```yaml
sources:
  gitlab:
    url: https://gitlab.com/api/v4/projects/70655681/packages/nuget/index.json
    username: your-username
    apiKey: ${GITLAB_API_KEY}
```

**Note:** GitHub sources automatically extract the username from the URL and don't require this field.

### Complete Configuration Example

```yaml
package: firebird

releases:
  source: https://github.com/FirebirdSQL/firebird
  flavors:
    current:
      - versionPattern: 'v(5\.\d+\.\d+)$'
      - assetsPattern: 'Firebird-[\d.]+-\d+-windows-(?<arch>[^-_.]+)\.exe$'
    v4:
      - versionPattern: 'v(4\.\d+\.\d+)$'
      - assetsPattern: 'Firebird-\d+\.\d+\.\d+\.\d+[-_]\d+[-_](?<arch>[^-_.]+)\.exe$'
    v3:
      - versionPattern: 'v(3\.\d+\.\d+)$'
      - assetsPattern: 'Firebird-\d+\.\d+\.\d+\.\d+[-_]\d+[-_](?<arch>[^-_.]+)\.exe$'
      - minimumVersion: 3.0.10

sources:
  community:
    url: https://community.chocolatey.org/api/v2
    apiKey: ${CHOCOLATEY_API_KEY}
  github:
    url: https://nuget.pkg.github.com/fdcastel/index.json
    apiKey: ${GITHUB_API_KEY}
  gitlab:
    url: https://gitlab.com/api/v4/projects/70655681/packages/nuget/index.json
    username: fdcastel
    apiKey: ${GITLAB_API_KEY}
```

---

## Template System

ChocoForge uses a powerful template system to generate package files dynamically from release data. Templates use the `{{ }}` syntax for variable substitution.

### Template Variables

When building a package, ChocoForge makes the following context available:

#### Basic Properties

- `{{version}}` - The semantic version (e.g., `5.0.1`)
- `{{tag_name}}` - The original GitHub release tag (e.g., `v5.0.1`)
- `{{name}}` - The GitHub release name/title
- `{{html_url}}` - URL to the GitHub release page
- `{{published_at}}` - Release publication date

#### Asset Properties

When an `assetsPattern` includes named capture groups, assets are organized by those properties:

```yaml
assetsPattern: 'myapp-(?<arch>x64|x86)\.zip$'
```

Available in templates:
- `{{assets.x64.browser_download_url}}` - Download URL for x64 asset
- `{{assets.x64.name}}` - Filename of x64 asset
- `{{assets.x64.size}}` - Size in bytes
- `{{assets.x86.browser_download_url}}` - Download URL for x86 asset
- `{{assets.x86.name}}` - Filename of x86 asset
- `{{assets.x86.size}}` - Size in bytes

#### SHA256 Checksums

ChocoForge provides automatic SHA256 checksum calculation:

- `{{assets.x64.sha256}}` - SHA256 hash of the x64 asset
- `{{assets.x86.sha256}}` - SHA256 hash of the x86 asset

**How it works:**
1. If the GitHub release includes a `digest` property with `sha256:` prefix, that value is used
2. Otherwise, ChocoForge downloads the file, calculates the SHA256, and caches it for 24 hours
3. Cached checksums are stored in `$env:TEMP\ChocoForge-HashCache.json`

**Note:** The `.sha256` suffix is a special handler. You can use it on any asset property that has a `browser_download_url`.

### Template Examples

#### `.nuspec` Template

```xml
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>firebird</id>
    <version>{{version}}</version>
    <title>Firebird</title>
    <authors>Firebird Foundation</authors>
    <projectUrl>https://firebirdsql.org/</projectUrl>
    <description>Firebird SQL database</description>
    <releaseNotes>{{html_url}}</releaseNotes>
  </metadata>
  <files>
    <file src="tools\**" target="tools" />
  </files>
</package>
```

#### Installation Script Template

```powershell
$ErrorActionPreference = 'Stop'

$packageName = 'firebird'
$version = '{{version}}'
$url64 = '{{assets.x64.browser_download_url}}'
$url32 = '{{assets.x86.browser_download_url}}'
$checksum64 = '{{assets.x64.sha256}}'
$checksum32 = '{{assets.x86.sha256}}'

$packageArgs = @{
    packageName    = $packageName
    fileType       = 'EXE'
    url            = $url32
    url64bit       = $url64
    checksum       = $checksum32
    checksumType   = 'sha256'
    checksum64     = $checksum64
    checksumType64 = 'sha256'
    silentArgs     = '/VERYSILENT /NORESTART'
}

Install-ChocolateyPackage @packageArgs
```

#### Handling Optional Assets

Sometimes assets may not exist for all architectures. Use concatenation to provide fallbacks:

```powershell
# Try x86 first, fall back to Win32 if not available
$url32 = '{{assets.x86.browser_download_url}}{{assets.Win32.browser_download_url}}'
$checksum32 = '{{assets.x86.sha256}}{{assets.Win32.sha256}}'
```

If `x86` doesn't exist, the first part resolves to empty string and the `Win32` value is used.

---

## Command Reference

ChocoForge provides three main commands for package management.

### `Get-ForgePackage`

Reads, resolves, and displays the Forge configuration with current publishing status.

#### Syntax

```powershell
Get-ForgePackage [[-Path] <String>] [-Passthru]
```

#### Parameters

- **Path** - Path to the `.forge.yaml` file. If not provided, searches for a single `.forge.yaml` file in the current directory.
- **Passthru** - Returns the configuration object instead of displaying it.

#### Examples

**Display configuration status:**
```powershell
Get-ForgePackage
```

**Display specific configuration:**
```powershell
Get-ForgePackage -Path 'C:\packages\myapp\myapp.forge.yaml'
```

**Get configuration object for further processing:**
```powershell
$config = Get-ForgePackage -Passthru
$config.versions | Select-Object version, flavor
```

#### Output

The command displays:
- **Package name**
- **Sources** with publishing status for each:
  - All versions published (green)
  - Some missing versions (yellow)
  - Not published on this source (gray)
  - Skip reasons (if API key is missing)
  - Warnings (if API key is stored in plain text)
- **Flavors** with version details:
  - Latest version available from GitHub
  - Current version on each source
  - Up-to-date or out-of-date status
  - List of missing versions

### `Build-ForgePackage`

Builds one or more Chocolatey packages for specific versions without publishing them.

#### Syntax

```powershell
Build-ForgePackage [[-Path] <String>] -Version <semver[]> [-RevisionNumber <int>] [-WhatIf] [-Verbose]
```

#### Parameters

- **Path** - Path to the `.forge.yaml` file. Defaults to current directory.
- **Version** - One or more versions to build. Must match versions available in the configuration.
- **RevisionNumber** - Optional revision number to use as the 4th segment of the package version. Defaults to 0.
- **WhatIf** - Shows what would happen without actually building.
- **Verbose** - Displays detailed build information.

#### Examples

**Build a single version:**
```powershell
Build-ForgePackage -Version 5.0.1
```

**Build multiple versions:**
```powershell
Build-ForgePackage -Version 5.0.1,5.0.0,4.0.5
```

**Build with revision number:**
```powershell
Build-ForgePackage -Version 5.0.1 -RevisionNumber 2
# Creates package version 5.0.1.2
```

**Test build without creating package:**
```powershell
Build-ForgePackage -Version 5.0.1 -WhatIf -Verbose
```

#### Output

Returns the full path to each built `.nupkg` file:
```
C:\packages\myapp\myapp.5.0.1.nupkg
```

#### Notes

- The command reads the `.nuspec` file (must be in the same directory as `.forge.yaml`)
- Templates are expanded with version-specific data
- Package files are created in the same directory as the `.forge.yaml`
- The command validates that requested versions exist in the configuration

### `Sync-ForgePackage`

Builds and publishes missing packages to all configured sources automatically.

#### Syntax

```powershell
Sync-ForgePackage [[-Path] <String>] [-WhatIf] [-Verbose]
```

#### Parameters

- **Path** - Path to the `.forge.yaml` file. If not provided, searches for a single `.forge.yaml` file in the current directory.
- **WhatIf** - Shows what would be published without actually publishing.
- **Verbose** - Displays detailed processing information.

#### Examples

**Sync all sources:**
```powershell
Sync-ForgePackage
```

**Sync with detailed output:**
```powershell
Sync-ForgePackage -Verbose
```

**Preview sync without publishing:**
```powershell
Sync-ForgePackage -WhatIf -Verbose
```

**Sync specific configuration:**
```powershell
Sync-ForgePackage -Path 'C:\packages\myapp\myapp.forge.yaml'
```

#### How It Works

1. **Loads configuration** from `.forge.yaml`
2. **Resolves versions** by fetching GitHub releases and filtering by flavor patterns
3. **Queries each source** to determine published versions
4. **Identifies missing versions** that exist in GitHub but not in each source
5. **Builds packages** for all missing versions (once, reused for all sources)
6. **Publishes packages** to each source that is missing them

#### Special Handling

**Chocolatey Community Repository:**
- Packages in moderation are detected to avoid duplicate submissions
- Uses `choco search` with exact version to check if already submitted

**GitHub Packages:**
- Automatically uses username from the repository URL
- Requires `${GITHUB_API_KEY}` environment variable

**GitLab Package Registry:**
- Requires `username` in the configuration
- Requires `${GITLAB_API_KEY}` environment variable

#### Output

Displays a summary:
```
Published 3 new packages.
  - Skipped sources: gitlab
```

#### Exit Behavior

- **Success**: Returns normally with summary
- **No missing versions**: Displays "No versions to publish"
- **Skip reasons**: Sources without API keys are skipped but reported
- **Errors**: Throws exceptions for unexpected failures

---

## Best Practices

### Security

1. **Never store API keys in `.forge.yaml`**
   ```yaml
   # ✅ Good
   apiKey: ${CHOCOLATEY_API_KEY}
   
   # ❌ Bad
   apiKey: abc123-your-actual-key-456def
   ```

2. **Set environment variables** in your profile or CI/CD:
   ```powershell
   $env:CHOCOLATEY_API_KEY = 'your-key-here'
   $env:GITHUB_API_KEY = 'your-token-here'
   $env:GITLAB_API_KEY = 'your-token-here'
   ```

3. **Add `.forge.yaml` to `.gitignore` if it contains sensitive data** (though using environment variables avoids this)

### Configuration Management

1. **Use specific version patterns** to avoid matching unwanted releases:
   ```yaml
   # ✅ Good - matches only stable releases
   versionPattern: 'v(\d+\.\d+\.\d+)$'
   
   # ❌ Bad - matches beta/rc releases too
   versionPattern: 'v(\d+\.\d+\.\d+)'
   ```

2. **Set `minimumVersion`** to avoid processing very old releases:
   ```yaml
   minimumVersion: 3.0.10
   ```

3. **Use descriptive flavor names** that indicate what they track:
   ```yaml
   flavors:
     current:  # Latest major version
     v4:       # Version 4.x branch
     beta:     # Pre-release versions
   ```

### Testing

1. **Always use `-WhatIf` first** when testing new configurations:
   ```powershell
   Sync-ForgePackage -WhatIf -Verbose
   ```

2. **Review configuration** before publishing:
   ```powershell
   Get-ForgePackage
   ```

3. **Build and test manually** before automated sync:
   ```powershell
   Build-ForgePackage -Version 1.2.3
   choco install myapp -source . -version 1.2.3
   ```

### Automation

1. **Use GitHub Actions or other CI/CD** for automated updates:
   ```yaml
   name: Sync Chocolatey Packages
   on:
     schedule:
       - cron: '0 0 * * *'  # Daily
   jobs:
     sync:
       runs-on: windows-latest
       steps:
         - uses: actions/checkout@v3
         - name: Sync packages
           run: Sync-ForgePackage -Verbose
           env:
             CHOCOLATEY_API_KEY: ${{ secrets.CHOCOLATEY_API_KEY }}
   ```

2. **Use `-Verbose`** in automation for better logging

3. **Monitor for errors** and set up notifications

### Performance

1. **SHA256 checksums are cached** for 24 hours in `$env:TEMP\ChocoForge-HashCache.json`
2. **GitHub API rate limits** apply - the module respects these limits
3. **Build once, publish many** - packages are built once and reused for all sources

---

## Examples

See the [Tests/assets](Tests/assets) folder for complete working examples:

- **[firebird-package](Tests/assets/firebird-package)** - Complex example with multiple flavors, architectures, and version branches
- **[qemu-img-package](Tests/assets/qemu-img-package)** - Simple single-flavor package

For real-world production examples, see the [chocolatey-packages](https://github.com/fdcastel/chocolatey-packages) repository.

---

## Troubleshooting

### "Environment variable X not set"

Set the required environment variable:
```powershell
$env:CHOCOLATEY_API_KEY = 'your-key'
```

### "Version X is not available in the configuration"

Check that the version exists in GitHub releases and matches your `versionPattern`:
```powershell
Get-ForgePackage | Select-Object -ExpandProperty versions
```

### "No .forge.yaml file found"

Specify the path explicitly:
```powershell
Get-ForgePackage -Path 'C:\path\to\package.forge.yaml'
```

### SHA256 checksums taking too long

Checksums are cached for 24 hours. First builds download files to calculate hashes, subsequent builds use the cache.

### Packages not appearing after publish

For Chocolatey Community: Packages go through moderation and may take time to appear. Use `choco search packagename --exact --version X.Y.Z` to verify submission.

---

## Contributing

Contributions are welcome! Please see the [GitHub repository](https://github.com/fdcastel/ChocoForge) for:
- Issue tracking
- Pull requests
- Documentation improvements

---

## License

Copyright (c) F.D.Castel. All rights reserved.

---

## Related Resources

- [Chocolatey Documentation](https://docs.chocolatey.org/)
- [Creating Chocolatey Packages](https://docs.chocolatey.org/en-us/create/create-packages)
- [Example Repository](https://github.com/fdcastel/chocolatey-packages)
- [PowerShell-YAML Module](https://github.com/cloudbase/powershell-yaml) 
