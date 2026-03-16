# PoshKelvin

PowerShell module to interact with [Kelvin](https://kelvin.ai/) instances and simplify API calls.

## Requirements

- PowerShell 5.1+ / PowerShell 7+
- Network access to your Kelvin instance

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

1. Run commands, for example list workloads for a cluster:

   ```powershell
   Get-KelvinWorkload -ClusterName my-cluster
   ```

1. View all commands provided by the module:

   ```powershell
   Get-Command -Module PoshKelvin
   ```

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
- **Network/timeouts** — ensure the Kelvin host is reachable from your machine
  and required ports are open.
- **Check available commands** — `Get-Command -Module PoshKelvin`

## Contributing

Contributions and issues are welcome. Please see [CONTRIBUTING.md](CONTRIBUTING.md)
for guidelines.

## License

This project is licensed under the [MIT License](LICENSE).
