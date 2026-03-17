# Changelog

All notable changes to PoshKelvin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.4.1] - 2026-03-17

### Fixed

- Fixed boolean filter parameters (`$Running`, `$Ready`, `$Enabled`, `$Staged`) incorrectly rejecting `$false` as a valid value by changing their type from `[bool]` to `[Nullable[bool]]`.
- Refactored `_GetParams` helper to simplify parameter extraction, removing the need for per-cmdlet workarounds.

### Changed

- Reorganized `src/public/` into tag-based subfolders (`AppManager`, `Asset`, `Bridge`, and so on) to improve source-code navigation. No functional changes.

## [0.4.0] - 2026-03-17

### Added

- `New-KelvinWorkload` — Deploy an application as a new workload to a cluster.
- `Start-KelvinWorkload` — Start one or more workloads.
- `Stop-KelvinWorkload` — Stop one or more workloads.
- `Install-KelvinWorkload` — Apply (finalize) one or more staged workloads.
- `Get-KelvinWorkloadConfiguration` — Retrieve a workload's configuration.
- `Set-KelvinWorkloadConfiguration` — Update a workload's configuration.
- `Get-KelvinWorkloadLog` — Retrieve logs for a workload.

### Changed

- Moved GitVersion execution into the build script (`GenerateVersion` task), removing the dependency on external GitHub Actions steps.
- CI workflow now delegates all build, test, and verification logic to `./build.ps1 -Task Package`.
- Added `Verify` task that smoke-tests the compiled module by importing it and listing exported commands.
- `Package` task now validates that `CHANGELOG.md` contains an entry matching the version being built.
- GitHub release title format changed from `v<x.y.z>` to `Version <x.y.z>`.

## [0.3.2] - 2026-03-17

### Fixed

- Fixed `ReleaseNotes` in the compiled module manifest now being set automatically at build time to a deep link pointing to the current version's section in `CHANGELOG.md`, instead of remaining as a stale static URL from a previous release.
- Fixed `Publish` task selecting an arbitrary manifest from the output directory; it now correctly selects the most recently written one.

## [0.3.1] - 2026-03-16

### Added

- Added a comprehensive Pester test suite covering all public cmdlets (`Connect-KelvinAccount`, `Export-KelvinWorkload`, `Invoke-KelvinApi`, `Remove-KelvinWorkload`, and all `Get-Kelvin*` cmdlets) and internal helpers (`_GetPaginatedData`, `_GetParams`).
- Added CI workflow for building and versioning the module.
- Added deployment workflow for handling pull-request merges and packaging.
- Added GitVersion configuration for the versioning strategy.

### Fixed

- Fixed `_GetParamName` incorrectly treating parameters with no aliases as having one, causing some cmdlets to display the error message `InvalidOperation: You cannot call a method on a null-valued expression`.

## [0.3.0] - 2026-01-08

### Changed

- Published PoshKelvin 0.3.0 to the PowerShell Gallery.
- Updated `Connect-KelvinAccount` so credentials can be supplied either through `-Credentials` or through the `KELVIN_USERNAME` and `KELVIN_PASSWORD` environment variables.
- Added explicit validation in `Connect-KelvinAccount` to fail when neither a credential object nor the required environment variables are available.
- No exported command additions or removals were identified in the published manifest when compared with 0.2.1.

## [0.2.1] - 2026-01-08

### Changed

- Published PoshKelvin 0.2.1 to the PowerShell Gallery.
- Updated pagination handling to load `System.Web` before parsing query strings for next-page links.
- Expanded `_GetParams` to support explicit bound-parameter maps in addition to call-stack inspection.
- Corrected `Get-KelvinInstanceSetting` to use the PowerShell `-and` operator in its detailed-output filter.
- Updated `Invoke-KelvinApi` to load `System.Net.Http` explicitly and use asynchronous request and stream APIs via `.Result`.
- No exported command additions or removals were identified in the published manifest when compared with 0.2.0.

## [0.2.0] - 2025-09-05

### Added

- Published PoshKelvin 0.2.0 to the PowerShell Gallery.
- `Export-KelvinWorkload` — Download a workload package.
- `Remove-KelvinWorkload` — Undeploy one or more workloads.

## [0.1.1] - 2025-07-08

### Added

- Initial public release of PoshKelvin.
- `Connect-KelvinAccount` — Authenticate against a Kelvin instance.
- `Invoke-KelvinApi` — Call any Kelvin API endpoint directly.
- `Get-KelvinApp` — List and query applications from the App Registry.
- `Get-KelvinAppManagerResource` — Get app manager details for a resource.
- `Get-KelvinAppResource` — List resources for a specific application.
- `Get-KelvinAsset` — List and query assets.
- `Get-KelvinAssetType` — List and query asset types.
- `Get-KelvinAuditLog` — List and query audit log entries.
- `Get-KelvinBridge` — List and query bridges.
- `Get-KelvinCluster` — List and query clusters.
- `Get-KelvinClusterNode` — List and query nodes in a cluster.
- `Get-KelvinClusterService` — List and query services in a cluster.
- `Get-KelvinDataStream` — List and query data streams.
- `Get-KelvinDataStreamSemanticType` — List and query data stream semantic types.
- `Get-KelvinDataStreamUnit` — List and query data stream units.
- `Get-KelvinDataTag` — List and query data tags and tag definitions.
- `Get-KelvinDataType` — List and query data types.
- `Get-KelvinFile` — List and query files in file storage.
- `Get-KelvinInstanceSetting` — List and query instance settings.
- `Get-KelvinInstanceStatus` — Get the status of the connected instance.
- `Get-KelvinParameterDefinition` — List and query parameter definitions.
- `Get-KelvinParameterResource` — List and query parameter resources.
- `Get-KelvinRecommendation` — List and query recommendations.
- `Get-KelvinRecommendationType` — List and query recommendation types.
- `Get-KelvinSecret` — List and query secrets.
- `Get-KelvinThread` — List and query threads.
- `Get-KelvinWorkload` — List and query workloads.
