# Contributing to PoshKelvin

Thank you for your interest in contributing to PoshKelvin!

## Getting Started

1. Fork the repository and clone your fork.
2. Install the build dependencies:

   ```powershell
   Install-Module InvokeBuild, ModuleBuilder -Scope CurrentUser
   ```

3. Build the module:

   ```powershell
   ./build.ps1
   ```

4. Make your changes in the `src/` directory.
5. Rebuild and verify the module imports correctly:

   ```powershell
   ./build.ps1
   $manifest = Get-ChildItem output -Filter '*.psd1' -Recurse | Select-Object -First 1
   Import-Module $manifest.FullName -Force
   ```

6. Run the tests:

   ```powershell
   ./build.ps1 -Task Test
   ```

   Tests that drive a real browser are skipped by default. To run them,
   install the interactive authentication prerequisites (see
   [docs/interactive-authentication.md](docs/interactive-authentication.md)),
   set `POSHKELVIN_BROWSER_TESTS=1`, and run that test file on its own:

   ```powershell
   $env:POSHKELVIN_BROWSER_TESTS = '1'
   Invoke-Pester ./tests/_InvokeKelvinBrowserLogin.Tests.ps1
   ```

## Coding Conventions

Please follow the conventions described in [AGENTS.md](AGENTS.md):

- **Language**: All text (comments, docs, strings, messages) must be in
  English (en-US).
- **Naming**: `PascalCase` for function names and parameters; `camelCase` or
  `snake_case` only for API field aliases.
- **Help**: Every public cmdlet must have `.SYNOPSIS`, `.DESCRIPTION`, and at
  least one `.EXAMPLE` (prefixed with `PS> `). Document parameters with inline
  comments above each parameter, not `.PARAMETER` entries.
- **Security**: Never commit credentials, internal hostnames, API keys, or
  proprietary references.

## Submitting Changes

1. Create a feature branch from `main`.
2. Make focused, well-described commits.
3. Open a pull request against `main` with a clear description of the change.
4. Ensure the module builds successfully before submitting.

## Reporting Issues

Use the [issue templates](.github/ISSUE_TEMPLATE/) to report bugs or request
features.
