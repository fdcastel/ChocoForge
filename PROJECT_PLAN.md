# ChocoForge — Project Review & Improvement Plan

## 1. Executive Summary

ChocoForge is a working PowerShell module that automates Chocolatey package creation and publishing from GitHub releases. It is in production and used via GitHub Actions to maintain ~5 packages across 3 NuGet-compatible sources (Chocolatey, GitHub Packages, GitLab).

**The module works**, but has accumulated complexity through iterative development. This plan documents the current state, identifies concrete problems, and proposes a simplified architecture with comprehensive testing.

---

## 2. Current Architecture

### 2.1 Module Structure

```
Public/       3 cmdlets (user-facing API)
  Build-ForgePackage     — Build .nupkg for specific versions
  Get-ForgePackage       — Display/return resolved configuration
  Sync-ForgePackage      — Build + publish missing versions to all sources

Private/      12 functions (internal)
  Read-ForgeConfiguration      — Parse + validate .forge.yaml
  Resolve-ForgeConfiguration   — Enrich config with GitHub releases + source versions
  Resolve-GitHubReleases       — Extract versions/assets from releases via regex
  Find-GitHubReleases          — Fetch releases from GitHub API
  Find-ChocolateyPublishedVersions — Query published versions via choco CLI
  Build-ChocolateyPackage      — Template expand + choco pack
  Publish-ChocolateyPackage    — choco push (with GitHub force-push)
  Expand-Template              — {{ mustache-style }} placeholder expansion
  Expand-EnvironmentVariables  — ${VAR_NAME} expansion
  Invoke-Chocolatey            — choco.exe wrapper
  Select-ObjectLike            — Generic object filter (hashtable-based query)
  Write-ForgeConfiguration     — Colorized console output
  Write-VerboseMark            — Verbose helper
```

### 2.2 Data Flow

```
.forge.yaml → Read-ForgeConfiguration → Resolve-ForgeConfiguration → Sync/Build/Get
                                              ↓                            ↓
                                    Find-GitHubReleases            Build-ChocolateyPackage
                                    Resolve-GitHubReleases              ↓
                                    Find-ChocolateyPublishedVersions   Expand-Template
                                                                       Invoke-Chocolatey (pack)
                                                                            ↓
                                                                   Publish-ChocolateyPackage
                                                                       Invoke-Chocolatey (push)
```

### 2.3 Production Usage (chocolatey-packages repo)

The GitHub Actions workflow (`update-all-packages.yml`) runs daily:
```yaml
Get-Item './*/*.forge.yaml' | ForEach-Object {
    Sync-ForgePackage $_.FullName -Verbose
}
```

Packages using ChocoForge (have `.forge.yaml`):
- **firebird** — 3 flavors (current/v4/v3), 2 architectures, complex install script
- **firebird-odbc** — 1 flavor, 2 architectures (x64/Win32)
- **qemu-img** — 1 flavor, single asset (zip)
- **opkssh** — 1 flavor, single asset (exe)

Packages NOT using ChocoForge (hardcoded versions):
- **msodbcsql** — Microsoft download, no GitHub releases
- **msoledbsql** — Microsoft download, no GitHub releases

---

## 3. Problems Identified

### 3.1 YAML Configuration Is Confusing

The flavor configuration uses **arrays of single-key dictionaries** instead of a simple dictionary. This is an artifact of YAML/PowerShell-YAML interaction:

```yaml
# Current (confusing) — each property is a separate list item
current:
  - versionPattern: 'v(5\.\d+\.\d+)$'
  - assetsPattern: 'Firebird-[\d.]+-\d+-windows-(?<arch>[^-_.]+)\.exe$'
  - minimumVersion: 5.0.1
```

The code in `Read-ForgeConfiguration` must iterate the list to find keys. In `Resolve-ForgeConfiguration`, `$flavor.versionPattern` is accessed directly (implying the YAML library merges them), but `Read-ForgeConfiguration` uses a loop to validate — inconsistent.

**Proposed:**
```yaml
# Simpler — each flavor is a plain object
current:
  versionPattern: 'v(5\.\d+\.\d+)$'
  assetsPattern: 'Firebird-[\d.]+-\d+-windows-(?<arch>[^-_.]+)\.exe$'
  minimumVersion: 5.0.1
```

### 3.2 No Revision Number Tracking

Chocolatey doesn't allow re-pushing a version. When a package needs a fix (e.g., install script bug), a 4th version segment must be added manually (e.g., `5.0.3.1`). This is currently:
- Not tracked in the YAML configuration
- Done manually outside the tool
- Not considered by `Sync-ForgePackage` (which only compares 3-part versions from GitHub)

**Need:** A way to declare revision overrides in the YAML, so `Sync-ForgePackage` can build and publish `5.0.3.1` instead of `5.0.3`.

### 3.3 No Support for Embedded Installers (VERIFICATION.txt)

Some Chocolatey packages embed the installer inside the `.nupkg` instead of downloading at install time. Chocolatey requires a `VERIFICATION.txt` file in these cases. This is not supported.

**Need:** A way to:
1. Download the asset and include it in the `.nupkg`
2. Generate a `VERIFICATION.txt` from a template with download URL and SHA256

### 3.4 `Resolve-ForgeConfiguration` Does Too Much

This single function:
1. Parses the GitHub URL
2. Fetches all GitHub releases
3. Expands all flavors
4. Queries all sources for published versions
5. Computes missing versions
6. Expands environment variables for API keys
7. Adds skip/warning metadata

This makes it impossible to test individual pieces and creates a monolithic "resolve everything" step.

### 3.5 `Resolve-GitHubReleases` Has Confusing Parameter Sets

- `VersionScriptBlock` parameter set exists but is never used (dead code)
- The `OptionalScript` parameter name is referenced in the code but doesn't exist in the parameter declarations — this is a **bug** (line with `$PSBoundParameters.ContainsKey('OptionalScript')`)
- The `process` block accumulates an array AND returns it — mixing pipeline and batch patterns
- Asset transposition is hard-coded to remove `'arch'` property name (see `$asset.PSObject.Properties.Remove('arch')`)

### 3.6 `Select-ObjectLike` Is Unused

This function is only used in tests (for manually filtering test data). No production code calls it. It's a generic query engine that adds complexity without purpose.

### 3.7 Version Comparison Is Fragile

In `Resolve-ForgeConfiguration`, the missing versions comparison treats `Revision=-1` as a wildcard. This is a workaround for GitHub releases having 3-part versions while Chocolatey can have 4-part versions. The logic is inline, duplicated, and not tested in isolation.

### 3.8 Test Coverage Is Mock-Heavy, Integration-Light

Current tests:
| Test File | What It Tests | Mocks |
|-----------|--------------|-------|
| `UtilityFunctions.Tests` | `Select-ObjectLike` filter | None (pure unit test) |
| `GitHubReleases.Tests` | `Find-GitHubReleases` + `Resolve-GitHubReleases` | `Invoke-RestMethod` (uses JSON fixtures) |
| `ChocolateyPackages.Tests` | `Find-ChocolateyPublishedVersions` | `Invoke-Chocolatey` |
| `Configuration-Firebird.Tests` | Read + Resolve + Build for firebird | `Invoke-RestMethod`, `Invoke-Chocolatey`, `Expand-EnvironmentVariables` |
| `Configuration-qemu-img.Tests` | Read + Resolve + Build for qemu-img | Same mocks |
| `Integration.Tests` | End-to-end build+publish | Skipped unless `APIKEY_GITHUB` set |

**Missing test coverage:**
- `Expand-Template` (no dedicated tests)
- `Expand-EnvironmentVariables` (no dedicated tests)
- `Publish-ChocolateyPackage` (no tests at all)
- `Write-ForgeConfiguration` (no tests)
- `Sync-ForgePackage` (no tests — the most critical function!)
- Version comparison logic (no isolated tests)
- Template SHA256 resolution (tested indirectly via build, but fragile)
- Error paths and edge cases
- Real GitHub API integration tests (safe — read-only)
- Real GitHub Packages integration tests (safe — deleteable)

### 3.9 Source-Specific Logic Is Scattered

GitHub, GitLab, and Chocolatey source handling is spread across multiple functions with `if/else` chains:
- `Resolve-ForgeConfiguration` — GitHub/GitLab username extraction
- `Publish-ChocolateyPackage` — Chocolatey URL rewrite (`community.chocolatey.org` → `push.chocolatey.org`), GitHub force-push
- `Sync-ForgePackage` — Chocolatey moderation check

### 3.10 Minor Issues

- `Read-ForgeConfiguration` has `[Parameter(Mandatory)]` on `$Path` but also has dead code for auto-discovery when `$Path` is empty (unreachable)
- `Invoke-Chocolatey` doesn't quote arguments (could break on paths with spaces)
- `Get-Sha256FromUrlWithCache` is defined inside `Expand-Template.ps1` (violates one-function-per-file rule)
- `Build-ChocolateyPackage` creates temp directories under `$env:TEMP/chocoforge` but never cleans up old builds
- The `Publish-ChocolateyPackage` force-push extracts package name using `.Split('.', 2)` which breaks for package names with dots (e.g., `qemu-img` is fine, but `my.package` would not be)
- `Write-ForgeConfiguration` uses `Write-Host` which can't be captured or suppressed

---

## 4. Proposed Changes

### Phase 1: Simplify Configuration (YAML Schema v2)

**Goal:** Simpler YAML, revision tracking, embedded installer support.

```yaml
# v2 schema
package: firebird

releases:
  source: https://github.com/FirebirdSQL/firebird
  flavors:
    current:
      versionPattern: 'v(5\.\d+\.\d+)$'
      assetsPattern: 'Firebird-[\d.]+-\d+-windows-(?<arch>[^-_.]+)\.exe$'
      minimumVersion: 5.0.1
      # NEW: revision overrides for Chocolatey re-submissions
      revisions:
        '5.0.3': 1    # Publish as 5.0.3.1
    v4:
      versionPattern: 'v(4\.\d+\.\d+)$'
      assetsPattern: 'Firebird-\d+\.\d+\.\d+\.\d+[-_]\d+[-_](?<arch>[^-_.]+)\.exe$'
      minimumVersion: 4.0.4

  # NEW: optional — embed assets in the .nupkg instead of downloading at install
  embed: false  # default

sources:
  chocolatey:
    url: https://community.chocolatey.org/api/v2
    apiKey: ${APIKEY_CHOCOLATEY}
  github:
    url: https://nuget.pkg.github.com/fdcastel/index.json
    apiKey: ${APIKEY_GITHUB}
  gitlab:
    url: https://gitlab.com/api/v4/projects/70655681/packages/nuget/index.json
    username: fdcastel
    apiKey: ${APIKEY_GITLAB}

# NEW: optional VERIFICATION.txt template (for embedded packages)
# verification: |
#   VERIFICATION
#   Download: {{assets.browser_download_url}}
#   SHA256: {{assets.sha256}}
```

Key changes:
- **Flavors are plain objects** (not arrays of single-key dictionaries)
- **`revisions` map** — per-version revision overrides
- **`embed` flag** — download and include assets in the .nupkg
- **`verification` template** — for VERIFICATION.txt generation

### Phase 2: Decompose `Resolve-ForgeConfiguration`

Break into focused functions:

```
Resolve-ForgeConfiguration  (current monolith)
  → Get-GitHubReleaseVersions   — Fetch + filter releases by flavor patterns
  → Get-SourcePublishedVersions  — Query a single source for versions
  → Compare-Versions            — Compute missing versions with revision awareness
```

### Phase 3: Simplify Internal Functions

1. **Remove `Select-ObjectLike`** — unused in production code; tests can use `Where-Object` directly
2. **Remove `VersionScriptBlock` parameter** from `Resolve-GitHubReleases` — dead code
3. **Fix the `OptionalScript` bug** in `Resolve-GitHubReleases`
4. **Extract `Get-Sha256FromUrlWithCache`** into its own file
5. **Make `TransposeProperty` generic** — don't hardcode `'arch'` removal; remove the property name stored in `$TransposeProperty`

### Phase 4: Embedded Installer Support

When `embed: true` in the YAML:

1. **During `Build-ChocolateyPackage`:**
   - Download each asset to the tools directory
   - If a `verification` template exists, expand it and write `tools/VERIFICATION.txt`
   - Update the `.nuspec` to include embedded files

2. **Template variables gain:**
   - `{{assets.x64.embedded_path}}` — relative path to embedded file
   - `{{assets.sha256}}` — already exists

3. **Install scripts change** from `Install-ChocolateyPackage` (downloads) to using the embedded file directly with `Install-ChocolateyInstallPackage`.

### Phase 5: Revision Number Tracking

With the `revisions` map in YAML:

```yaml
revisions:
  '5.0.3': 1
```

- `Sync-ForgePackage` builds `5.0.3.1` when the configured revision is set
- Version comparison accounts for this: `5.0.3.1` on Chocolatey satisfies `5.0.3` from GitHub
- `Build-ForgePackage` still supports `-RevisionNumber` for ad-hoc builds

### Phase 6: Comprehensive Test Suite

#### 6.1 Pure Unit Tests (no mocks, no network)

| Test | Functions Covered |
|------|-------------------|
| `Expand-Template.Tests` | `Expand-Template` — all placeholder types, missing values, nested properties |
| `Expand-EnvironmentVariables.Tests` | `Expand-EnvironmentVariables` — set/unset vars, multiple vars, no vars |
| `Resolve-GitHubReleases.Tests` | `Resolve-GitHubReleases` — version extraction, asset filtering, transposition, minimum version |
| `Compare-Versions.Tests` | Version comparison with revisions (new function) |
| `Read-ForgeConfiguration.Tests` | YAML validation — missing fields, invalid values, v2 schema |

#### 6.2 Integration Tests (real network, safe targets only)

| Test | What It Does | Target |
|------|-------------|--------|
| `GitHub-API.Tests` | `Find-GitHubReleases` against real repos | GitHub API (read-only, safe) |
| `GitHub-Packages.Tests` | Build + publish + query + delete | GitHub Packages (safe, deleteable) |
| `GitLab-Packages.Tests` | Build + publish + query + delete | GitLab Registry (safe, deleteable) |
| `Build-Package.Tests` | Full build pipeline, verify .nupkg contents | Local only (choco pack) |
| `Sync-E2E.Tests` | Full `Sync-ForgePackage` with real GitHub/GitLab | GitHub + GitLab (safe) |
| `Embed-Package.Tests` | Build with embedded installer, verify VERIFICATION.txt | Local only |

**Never test against Chocolatey community repo** — pushes are permanent.

#### 6.3 Test Infrastructure

- Use `fdcastel/qemu-img-windows-x64` as a real GitHub repo for API tests (small, stable releases)
- Use GitHub Packages and GitLab as safe publish/delete targets
- Guard integration tests with environment variable checks (`-Skip:(-not $env:APIKEY_GITHUB)`)
- Keep existing JSON fixtures for offline/CI unit tests

---

## 5. Implementation Order

### Step 1 — Fix bugs and clean up (low risk)
1. Fix the `OptionalScript` bug in `Resolve-GitHubReleases`
2. Extract `Get-Sha256FromUrlWithCache` to its own file
3. Fix hardcoded `'arch'` removal in transposition
4. Remove dead auto-discovery code in `Read-ForgeConfiguration`
5. Remove `Select-ObjectLike` (move inline filtering to tests)
6. Remove `VersionScriptBlock` parameter set

### Step 2 — Add unit tests for existing functions
1. `Expand-Template.Tests.ps1`
2. `Expand-EnvironmentVariables.Tests.ps1`
3. `Resolve-GitHubReleases.Tests.ps1` (expand existing)
4. `Read-ForgeConfiguration.Tests.ps1`

### Step 3 — Simplify YAML schema
1. Support both v1 (array-of-dicts) and v2 (plain object) flavor syntax during transition
2. Migrate all `.forge.yaml` files to v2
3. Drop v1 support

### Step 4 — Add revision tracking
1. Add `revisions` map to YAML schema
2. Modify version comparison logic
3. Modify `Sync-ForgePackage` to use configured revisions
4. Add tests

### Step 5 — Add embedded installer support
1. Add `embed` flag to YAML
2. Modify `Build-ChocolateyPackage` to download and embed assets
3. Add `verification` template support
4. Add tests

### Step 6 — Integration tests
1. GitHub API tests (read-only)
2. GitHub Packages publish/delete cycle
3. GitLab Packages publish/delete cycle
4. Full Sync-ForgePackage E2E test

### Step 7 — Decompose Resolve-ForgeConfiguration
1. Extract focused functions
2. Update callers
3. Add tests for each piece

---

## 6. Files to Change/Create

### Modified Files
| File | Changes |
|------|---------|
| `Private/Read-ForgeConfiguration.ps1` | Support v2 flavor syntax, `revisions`, `embed`, `verification` |
| `Private/Resolve-ForgeConfiguration.ps1` | Decompose; use revision map; fix version comparison |
| `Private/Resolve-GitHubReleases.ps1` | Remove dead code; fix OptionalScript bug; fix hardcoded arch |
| `Private/Expand-Template.ps1` | Extract `Get-Sha256FromUrlWithCache`; add `embedded_path` variable |
| `Private/Build-ChocolateyPackage.ps1` | Support embedded assets + VERIFICATION.txt |
| `Public/Sync-ForgePackage.ps1` | Use revision numbers from config |
| `Public/Build-ForgePackage.ps1` | Use revision numbers from config (fall back to `-RevisionNumber` param) |

### New Files
| File | Purpose |
|------|---------|
| `Private/Get-Sha256FromUrlWithCache.ps1` | Extracted from Expand-Template.ps1 |
| `Private/Compare-Versions.ps1` | Isolated version comparison with revision awareness |
| `Tests/Expand-Template.Tests.ps1` | Unit tests for template expansion |
| `Tests/Expand-EnvironmentVariables.Tests.ps1` | Unit tests for env var expansion |
| `Tests/Read-ForgeConfiguration.Tests.ps1` | Unit tests for YAML validation |
| `Tests/Resolve-GitHubReleases.Tests.ps1` | Expanded unit tests |
| `Tests/Compare-Versions.Tests.ps1` | Version comparison tests |
| `Tests/GitHub-API.Tests.ps1` | Real GitHub API integration |
| `Tests/GitHub-Packages.Tests.ps1` | Real publish/delete cycle |
| `Tests/GitLab-Packages.Tests.ps1` | Real publish/delete cycle |
| `Tests/Build-Package.Tests.ps1` | Full build pipeline tests |
| `Tests/Embed-Package.Tests.ps1` | Embedded installer tests |
| `Tests/Sync-E2E.Tests.ps1` | Full end-to-end sync tests |

### Deleted Files
| File | Reason |
|------|--------|
| `Private/Select-ObjectLike.ps1` | Unused in production code |
| `Tests/UtilityFunctions.Tests.ps1` | Tests for `Select-ObjectLike` (removed) |

---

## 7. Risk Assessment

| Change | Risk | Mitigation |
|--------|------|-----------|
| YAML schema v2 | Medium — breaks existing configs | Transition period supporting both formats |
| Remove Select-ObjectLike | Low — unused in prod | Search for all usages first |
| Decompose Resolve-ForgeConfiguration | Medium — many callers | Keep function signature; change internals |
| Embedded installer support | Low — additive feature | New flag, defaults to current behavior |
| Revision tracking | Low — additive feature | Defaults to revision 0 (current behavior) |
| Integration tests | Low — read-only or safe targets | Never touch Chocolatey community repo |

---

## 8. Success Criteria

1. All existing `chocolatey-packages` workflows continue to work unchanged (or with minimal `.forge.yaml` migration)
2. `Sync-ForgePackage` handles revision numbers from YAML config
3. `Build-ForgePackage` can produce embedded-installer packages with VERIFICATION.txt
4. Test suite covers all functions with both unit and integration tests
5. Integration tests run against real GitHub/GitLab APIs (guarded by env vars)
6. No test ever touches Chocolatey community repository
7. Codebase is simpler: fewer functions, clearer responsibilities, one function per file
