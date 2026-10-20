# PoshKelvin

PowerShell module to interact with [Kelvin](https://kelvin.ai/) instances and simplify API calls.

## Requirements

- PowerShell 5.1+ / PowerShell 7+
- Network access to your Kelvin instance
- For interactive sign-in: a default browser and access to a local callback
  port (default: 38638). No Playwright installation is required for native OAuth.
  See [Interactive authentication](docs/interactive-authentication.md).

## Installation

Install from the [PowerShell Gallery](https://www.powershellgallery.com/packages/PoshKelvin):

```powershell
Install-Module PoshKelvin -Scope CurrentUser
```

## Quick start

1. Enter your credentials:

   ```powershell
   $cred = Get-Credential
   ```

1. Connect to the desired Kelvin instance:

   ```powershell
   Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Credential $cred
   ```

   Alternatively, sign in through your default browser using native OAuth. This works
   with SSO and multi-factor authentication (see
   [Interactive authentication](docs/interactive-authentication.md)):

   ```powershell
   Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Interactive
   ```

   The default redirect is `http://localhost:38638/` (Kelvin 5.2.0+).
   Set `KELVIN_AUTH_REDIRECT_URI` if your administrator registered a different
   loopback URL. If native login is unavailable, use `-Interactive -UseInternalBrowser`
   for the built-in browser fallback (PowerShell 7+ and a one-time setup required;
   see [docs/interactive-authentication.md](docs/interactive-authentication.md)).

1. Run commands, for example list workloads for a cluster:

   ```powershell
   Get-KelvinWorkload -ClusterName my-cluster
   ```

1. View all commands provided by the module:

   ```powershell
   Get-Command -Module PoshKelvin
   ```

1. When you are done, clear the cached session and credentials:

   ```powershell
   Disconnect-KelvinAccount
   ```

## Token renewal

API commands automatically renew tokens when needed after `Connect-KelvinAccount`;
manual renewal is not required. The default refresh window is 120 seconds
(two minutes); override it with `Connect-KelvinAccount -RefreshWindow`.
Token lifetimes are taken from the authentication response, not hardcoded.
To test renewal or renew tokens early:

```powershell
Update-KelvinToken -Verbose
```

To re-authenticate with the cached credentials and request both tokens:

```powershell
Update-KelvinToken -Force -Verbose
```

Both commands return `Status` (`Refreshed` or `Reauthenticated`),
`AccessTokenExpiresAt` and `RefreshTokenExpiresAt` (UTC), without exposing tokens
or credentials. Failed operations raise an error and return no status object.
Normal refresh does not fall back to re-authentication; use `-Force` if the
refresh token is unavailable or rejected.

Interactive sessions store no password. When their refresh token expires, run
`Connect-KelvinAccount -Interactive` again; `-Force` is not available for them.

## Streaming list defaults

`Get-KelvinAuditLog`, `Get-KelvinWorkload`, `Get-KelvinApp`,
`Get-KelvinAsset`, `Get-KelvinCluster`, and `Get-KelvinSecret` use parsed
streaming by default to avoid repeated page requests for large collections.
Their output objects and detail lookups are unchanged. Select another mode
explicitly when needed:

```powershell
Get-KelvinWorkload -PaginationMode Cursor
Get-KelvinAsset -PaginationMode Limits
```

Other cmdlets and direct `Invoke-KelvinApi` calls retain their existing defaults.
These cmdlets were selected for potentially high-volume collections; small
lookup lists keep cursor pagination. In a live measurement, listing
2,722 workloads took about 5 seconds with streaming versus about 98 seconds
with the default 20-item cursor pages. Actual gains depend on collection size
and network latency.

`-Detailed` still performs one additional request per item, so those requests
can dominate the overall runtime.

A stream failure after records have been emitted is reported without replaying
the stream; use `-ErrorAction Stop` when incomplete results must fail the operation.

## Invoke-KelvinApi

For operations not yet wrapped by cmdlets, use `Invoke-KelvinApi` to call the
Kelvin API endpoints directly. This helper handles the base URL and
authentication (after `Connect-KelvinAccount`).

- Example — stop a workload:

  ```powershell
  Invoke-KelvinApi 'workloads/my_workload/stop'
  ```

- Example — POST with body:

  ```powershell
  Invoke-KelvinApi 'workloads/apply' -Method POST -Body @{
      workload_names = @('workload1', 'workload2')
  }
  ```

Notes:

- The first parameter is the API path relative to the base Kelvin URL.
- Use `-Method` to specify HTTP verb (GET, POST, PUT, DELETE, etc.).
- Pass simple hashtables for JSON bodies; the module will serialize them.
- Cursor (default) and limits pagination automatically return results from all
  remaining pages, preserving query filters, HTTP method, and request body.
  Authentication is checked before every page request.
- An HTTP 401 triggers token renewal and one retry of that same request.
  If renewal fails or the retry is rejected, the error is surfaced. Other HTTP
  errors are not retried. This also applies before a JSON stream or raw download
  starts; an already-started stream is never replayed.
- Use `-PaginationMode Limits -Parameters @{ page_size = 100 }` for
  page-number pagination, or `-PaginationMode Stream` to
  receive parsed JSON objects incrementally without buffering the whole response.
- `-PaginationMode Cursor|Limits|Stream` selects parsed-result pagination and
  overrides `pagination_type` and `Accept` without modifying your hashtable.
  When omitted, existing query/header settings still apply (cursor by default).
  The endpoint must support the selected mode.
- `-AsStream` instead returns a raw response stream, suitable for binary
  downloads; the caller must dispose that stream after use. It cannot be combined
  with `-PaginationMode`.
- If a later page or stream record fails, previously emitted results cannot be
  withdrawn. Use `-ErrorAction Stop` when incomplete results must fail the operation.
- At the moment, only Kelvin Cloud instances are supported. Support for local
  Kelvin instances will be added later.

## Examples

- Get detailed workload info:

  ```powershell
  Get-KelvinWorkload -ClusterName my-cluster -Name my-app -Detailed
  ```

- Stop a workload via raw API:

  ```powershell
  Invoke-KelvinApi 'workloads/my-app/stop'
  ```

## Troubleshooting

- **Authentication errors** — re-run `Connect-KelvinAccount` with valid
  credentials.
- **Interactive sign-in problems**: see the troubleshooting section in
  [Interactive authentication](docs/interactive-authentication.md#troubleshooting).
- **Network/timeouts** — ensure the Kelvin host is reachable from your machine
  and required ports are open.
- **Check available commands** — `Get-Command -Module PoshKelvin`

## Contributing

Contributions and issues are welcome. Please see [CONTRIBUTING.md](CONTRIBUTING.md)
for guidelines.

## License

This project is licensed under the [MIT License](LICENSE).
