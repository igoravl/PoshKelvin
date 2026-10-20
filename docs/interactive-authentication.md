# Interactive authentication

`Connect-KelvinAccount -Interactive` uses native OAuth authorization-code login
with PKCE (S256). It opens your default browser, lets you complete single sign-on
(SSO) and multi-factor authentication, and receives the result through a local
HTTP callback. It never sees or stores your password and does not read the Kelvin
UI session. No Playwright or Chromium installation is needed.

## Requirements

- PowerShell 5.1 or later and an accessible default browser.
- An HTTPS Kelvin instance with the public Keycloak client `kelvin-client`,
  authorization-code login and PKCE enabled.
- A registered loopback redirect URI. Kelvin 5.2.0+ registers
  `http://localhost:38638/*` by default; only port **38638** is allowed by that
  default registration.
- Permission to listen on the local callback port. The browser must be able to
  reach the PowerShell host through that loopback address.

## Signing in with native OAuth

```powershell
Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Interactive
```

1. PoshKelvin starts a listener on `http://localhost:38638/`, then opens your
   default browser on the Keycloak authorization endpoint.
1. Sign in through the identity provider as usual. Your existing browser SSO
   session can be reused.
1. Keycloak redirects to the local listener. PoshKelvin validates a random state
   value and exchanges the authorization code using a per-login PKCE verifier.
1. The listener closes, and the tokens are stored in the module session.

The authorization request uses `client_id=kelvin-client`, `scope=openid`,
`response_type=code` and `code_challenge_method=S256`. No client secret is used.
The same redirect URI is used for authorization and token exchange.

PoshKelvin waits up to 300 seconds. Use `-Timeout 600` to allow more time.
Closing the browser does not signal cancellation; interrupt the command or let
it time out. A failure leaves any previously established module session intact.
The browser tab can be closed after the callback; PoshKelvin does not close your
normal browser or clear its cookies.

### Overriding the redirect URI

If your installation registers a different callback URL, set:

```powershell
$env:KELVIN_AUTH_REDIRECT_URI = 'http://localhost:45678/oauth/callback'
Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Interactive
```

The override must be an absolute HTTP loopback URL using `localhost` or
`127.0.0.1`. Literal IPv6 URLs are not supported by the HTTP listener.
Query strings, fragments, embedded credentials and non-loopback hosts are
rejected. Custom paths and ports are supported, but the complete URL must
match the client's redirect registration. Setting this variable does **not**
change Keycloak's allowlist. It is ignored for password and Playwright login.
Remove the variable to restore the default:

```powershell
Remove-Item Env:\KELVIN_AUTH_REDIRECT_URI
```

## Playwright fallback

If the installation does not support the native flow, select the existing
UI-session approach explicitly:

```powershell
Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Interactive -UsePlaywright
```

There is no automatic fallback after OAuth failure. Playwright requires
PowerShell 7+, [Playwright for .NET](https://playwright.dev/dotnet/), Chromium
and a graphical desktop (X11, Wayland or WSLg on Linux).

### Installing the Playwright prerequisites

PoshKelvin includes the script `Install-KelvinInteractivePrerequisites.ps1`.
It downloads the Microsoft.Playwright package from nuget.org and keeps only
the files your platform needs. It then installs Chromium into a per-user
folder. Nothing is installed system-wide and administrator rights are not
required.

```powershell
$module = Get-Module PoshKelvin -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
& (Join-Path $module.ModuleBase 'scripts/Install-KelvinInteractivePrerequisites.ps1')
```

If the prerequisites are missing when you run `Connect-KelvinAccount -Interactive -UsePlaywright`
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

### Playwright setup script options

| Parameter           | Description                                                        |
|---------------------|--------------------------------------------------------------------|
| `-Path`             | Installation folder (overrides `POSHKELVIN_PLAYWRIGHT_PATH`).      |
| `-Force`            | Reinstall even when the files are already present.                 |
| `-WithDependencies` | Linux only: also install Chromium's system libraries (needs root).  |
| `-WhatIf`           | Show what would be installed without changing anything.            |

On a minimal Linux system Chromium may fail to start because shared libraries
are missing. In that case run the script with `-WithDependencies` as root, or
install the libraries with your distribution's package manager.

### Signing in with Playwright

```powershell
Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Interactive -UsePlaywright
```

1. A Chromium window opens on the Kelvin login page.
1. Sign in as usual. The identity provider may ask for SSO or a second factor.
1. Kelvin redirects back to its own page after the sign-in. PoshKelvin then
   reads the session from `/api/auth/session` and closes the browser.

By default PoshKelvin waits up to 300 seconds. To change the wait, use
`-Timeout` (in seconds):

```powershell
Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Interactive -UsePlaywright -Timeout 600
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

- **"Invalid parameter: redirect_uri"**: check `KELVIN_AUTH_REDIRECT_URI` against
  the client's registered URLs. Kelvin's default permits port 38638, not an
  arbitrary port.
- **HTTP 403 after Microsoft sign-in**: this may require investigation by the
  Kelvin administrator. Note the failing page's origin and path, but redact
  query values, authorization codes, state and tokens before sharing diagnostics.
  Native login eventually times out if no callback arrives. You can explicitly
  try `-Interactive -UsePlaywright`.
- **"Cannot start the OAuth callback listener"**: another login or application
  may be using the port. Close that login or ask the administrator to register
  another redirect. On Windows, HTTP listener URL reservations may also require
  administrator configuration; do not run a privileged shell just to sign in.
- **WSL, SSH or remote shells**: the default browser must be reachable and its
  `localhost` callback must reach this PowerShell process. Check WSL localhost
  forwarding if the browser runs on Windows. A remote browser's loopback address
  normally refers to the wrong host; use a local PowerShell session instead.
- **"OAuth callback state ... does not match"**: no code was exchanged. Start a
  new login and do not reuse callback URLs from old tabs.
- **"OAuth authorization-code exchange failed"**: verify the client's redirect,
  authorization-code grant and PKCE settings with the administrator.
- **"Playwright authentication requires PowerShell 7 or later"**: omit
  `-UsePlaywright` for native OAuth, or run the fallback from `pwsh`.
- **"Interactive authentication prerequisites are missing"**: run the
  prerequisites script. If you use a custom folder, make sure
  `POSHKELVIN_PLAYWRIGHT_PATH` points to it in the current session.
- **The Playwright browser does not open on Linux or WSL**: check that a display is
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
- Native login accepts only loopback HTTP callbacks, checks state, and uses PKCE.
  It sends tokens only over HTTPS to the selected Kelvin instance. The callback
  page never displays codes or tokens.
- Native token expiration dates come from the token endpoint response. JWT
  claims are decoded only for username metadata; the Kelvin API validates tokens.
- With `-UsePlaywright`, PoshKelvin reads the session JSON only from the selected
  Kelvin instance after the identity provider callback. JWT claims are used for
  expiration times, client ID and username metadata, not authorization decisions.
