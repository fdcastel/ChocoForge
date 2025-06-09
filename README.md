# ChocoForge

<img src="docs/ChocoForge-Logo.png" alt="ChocoForge Logo" width="180" align="right" />

PowerShell toolkit for automating the creation, management, and publishing of Chocolatey packages. 

It is designed to simplify the process of keeping Chocolatey repositories up-to-date with the latest releases from upstream projects, supporting advanced templating, flexible configuration, and multi-source publishing.

## Features

- **Declarative YAML Configuration**: Define your package, release sources, flavors, and publishing sources in a single `.forge.yaml` file.
- **GitHub Release Integration**: Automatically fetches and processes releases and assets from GitHub repositories.
- **Template-Based Packaging**: Uses template substitution to generate nuspec files and scripts from your configuration and release data.
- **Multi-source Publishing**: Publish packages to multiple Chocolatey-compatible repositories, including the official community feed, GitHub NuGet feeds, and custom endpoints.
- **Force-Push Support**: Optionally force-push to GitHub NuGet feeds by deleting existing versions if needed (GitHub only).

## Example usage

<img src="docs/Example.png" alt="ChocoForge Example Workflow" width="600" />

## Getting Started

1. **Prepare Your Configuration**
   - Create a `.forge.yaml` file (see `Samples/` for examples).
   - Define your package name, GitHub release source, flavors, and publishing sources.

2. **Review Status**
   - Get a summary of your configuration and publishing status:
     ```powershell
     Get-ForgeConfiguration -Path 'Samples/firebird/firebird.forge.yaml'
     ```

3. **Build and Publish Packages**

   - Or sync everything in one go:
     ```powershell
     Sync-ForgePackage -Path 'Samples/firebird/firebird.forge.yaml' -Verbose
     ```

## Configuration

A typical `.forge.yaml` file includes:
- `package`: The package name.
- `releases.source`: The GitHub repository URL to fetch releases from.
- `releases.flavors`: Define one or more flavors (e.g., current, beta) for different release patterns.
- `sources`: One or more publishing Chocolatey (NuGet) sources, each with a URL and API key (can use environment variables).

See the `Samples/` directory for real-world examples.

## Requirements
- PowerShell 7.5 or later
- Chocolatey CLI (`choco.exe`) installed and available in your PATH

## Tips
- Store API keys in environment variables for security.
- Use `-WhatIf` and `-Verbose` for safe, transparent operations.
- Review the output of `Get-ForgeConfiguration` before publishing.


---
For more details, see the inline help in each function or explore the `Samples/` and `Tests/` directories for usage patterns and test cases.
