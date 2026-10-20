# Interactive authentication

`Connect-KelvinAccount -Interactive` signs in through the Kelvin web login
page. Use it with any identity provider configured in Kelvin, including single
sign-on (SSO) and multi-factor authentication. PoshKelvin opens a browser
window, waits while you sign in, and then reads the session tokens from the
Kelvin UI. It never sees or stores your password.

## Requirements

- PowerShell 7 or later. Windows PowerShell 5.1 supports only credential
  (username and password) authentication.
- [Playwright for .NET](https://playwright.dev/dotnet/) and a Chromium browser,
  installed once per user with the prerequisites script described below.
- A desktop session that can show a browser window. On Linux this means an X11
  or Wayland display, such as WSLg under WSL.

## Installing the prerequisites

PoshKelvin includes the script `Install-KelvinInteractivePrerequisites.ps1`.
It downloads the Microsoft.Playwright package from nuget.org and keeps only
the files your platform needs. It then installs Chromium into a per-user
folder. Nothing is installed system-wide and administrator rights are not
required.

```powershell
$module = Get-Module PoshKelvin -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
& (Join-Path $module.ModuleBase 'scripts/Install-KelvinInteractivePrerequisites.ps1')
```

If the prerequisites are missing when you run `Connect-KelvinAccount -Interactive`
in an interactive session, PoshKelvin offers to run the script for you.

| Platform    | Default location                                          |
|-------------|-----------------------------------------------------------|
| Windows     | `%LOCALAPPDATA%\PoshKelvin\Playwright`                    |
| Linux/macOS | `$XDG_DATA_HOME/PoshKelvin/Playwright` (or `~/.local/share/PoshKelvin/Playwright`) |

To use another folder, set the `POSHKELVIN_PLAYWRIGHT_PATH` environment
variable before running the script and before connecting, or pass `-Path` to
the script. PoshKelvin reads the same variable when it connects.

The download is about 380 MB: about 210 MB for the Playwright package and
170 MB for Chromium. After installation the files use about 550 MB of disk.

### Script options

| Parameter           | Description                                                        |
|---------------------|--------------------------------------------------------------------|
| `-Path`             | Installation folder (overrides `POSHKELVIN_PLAYWRIGHT_PATH`).      |
| `-Force`            | Reinstall even when the files are already present.                 |
| `-WithDependencies` | Linux only: also install Chromium's system libraries (needs root).  |
| `-WhatIf`           | Show what would be installed without changing anything.            |

On a minimal Linux system Chromium may fail to start because shared libraries
are missing. In that case run the script with `-WithDependencies` as root, or
install the libraries with your distribution's package manager.

## Signing in

```powershell
Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Interactive
```

1. A Chromium window opens on the Kelvin login page.
1. Sign in as usual. The identity provider may ask for SSO or a second factor.
1. Kelvin redirects back to its own page after the sign-in. PoshKelvin then
   reads the session from `/api/auth/session` and closes the browser.

By default PoshKelvin waits up to 300 seconds. To change the wait, use
`-Timeout` (in seconds):

```powershell
Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Interactive -Timeout 600
```

The browser uses a temporary profile, so no cookies or other data are kept
after it closes. If you close the window before signing in, or the timeout
expires, the command fails and keeps any existing session.

## Token lifetime and renewal

Interactive sessions renew themselves the same way as credential sessions.
API commands refresh the access token with the refresh token before it
expires, and `Update-KelvinToken` refreshes it on demand.

PoshKelvin does not store a password for an interactive session, so it cannot
re-authenticate silently. Once the refresh token expires (Kelvin usually
issues refresh tokens valid for a few hours) or is revoked, commands fail with
a message asking you to run `Connect-KelvinAccount -Interactive` again.
`Update-KelvinToken -Force` is not available for interactive sessions for the
same reason.

`Disconnect-KelvinAccount` revokes the refresh token on the server and clears
the local session.

## Troubleshooting

- **"Interactive authentication requires PowerShell 7 or later"**: run the
  command from `pwsh` instead of Windows PowerShell.
- **"Interactive authentication prerequisites are missing"**: run the
  prerequisites script. If you use a custom folder, make sure
  `POSHKELVIN_PLAYWRIGHT_PATH` points to it in the current session.
- **The browser does not open on Linux or WSL**: check that a display is
  available (`echo $DISPLAY` or `echo $WAYLAND_DISPLAY`), and install
  Chromium's dependencies with `-WithDependencies` if needed.
- **"Timed out after N seconds"**: sign in faster, or use a larger `-Timeout`.
- **"Unable to read the session from the Kelvin UI"**: the instance may use a
  different UI layout. Run the command with `-Verbose` to see the URLs that
  were tried, and open an issue.
- **"The interactive session has expired"**: run
  `Connect-KelvinAccount -Interactive` again.

## Security notes

- The tokens are kept in memory only, in the module session, as they are for
  credential sessions.
- PoshKelvin reads the session JSON only from the Kelvin instance you
  connect to, and only after the identity provider redirects back to it.
- The JWT claims are decoded only to read expiration times, the client ID and
  the username. They are not used to make security decisions; the Kelvin API
  validates the tokens.
