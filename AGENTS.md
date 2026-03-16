# AGENTS.md — PoshKelvin

## Project overview

PoshKelvin is an open-source PowerShell module that wraps the
[Kelvin](https://kelvin.ai/) REST API. It targets PowerShell 5.1+ and
PowerShell 7+ and is published to the PowerShell Gallery.

### Repository layout

```text
src/                   Module source (compiled by ModuleBuilder)
  public/              Exported cmdlet functions
  private/             Internal helper functions
  enums/               Enum definitions
  PoshKelvin.psd1      Module manifest
  build.psd1           ModuleBuilder configuration
docs/                  Documentation and API specifications
build.ps1              Build entry-point (InvokeBuild)
poshkelvin.build.ps1   InvokeBuild task definitions
```

### Build & test

```powershell
# Build the module (requires InvokeBuild + ModuleBuilder)
./build.ps1

# Run tests (requires Pester)
Invoke-Build Test
```

## Coding conventions

### PowerShell style

- Use `PascalCase` for function names and parameters.
- Use `camelCase` or `snake_case` only for API field aliases.
- Prefer `[CmdletBinding()]` and `[OutputType()]` on every public function.
- Use `$PSCmdlet.ShouldProcess` for destructive operations.

### Comment-based help

Every **public** cmdlet must include comment-based help with at least:

1. `.SYNOPSIS` — A single-line summary.
2. `.DESCRIPTION` — A more detailed explanation.
3. `.EXAMPLE` — At least one usage example; add more when the cmdlet has
   multiple parameter sets or common usage patterns. The first line of each
   example must start with the `PS>` prompt prefix. Example:

```powershell
.EXAMPLE
    PS> Get-KelvinCluster -Status online

    Lists all online clusters.
```

**Parameter documentation** must be written as inline comments directly above
each parameter declaration inside the `param()` block — **not** as `.PARAMETER`
entries in the help header. Example:

```powershell
param (
    # The name of the cluster to query.
    [Parameter(Mandatory)]
    [string] $ClusterName,

    # Return detailed information for each result.
    [Parameter()]
    [switch] $Detailed
)
```

### Sensitive information

This project is open-source. **Never** commit:

- Internal hostnames, IP addresses, or URLs.
- Credentials, tokens, or API keys.
- Company-specific or proprietary references.
- Internal project codenames or repository paths.

## Dependencies

| Module         | Purpose                  |
|----------------|--------------------------|
| InvokeBuild    | Build orchestration      |
| ModuleBuilder  | Module compilation       |
| Pester         | Testing framework        |

## Language

All text visible to users — including code comments, documentation, strings,
log messages, error messages, and commit messages — **must be written in
English (en-US)**.
