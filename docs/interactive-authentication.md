# Interactive authentication

`Connect-KelvinAccount -Interactive` uses native OAuth authorization-code login
with PKCE (S256). It opens your default browser, lets you complete single sign-on
(SSO) and multi-factor authentication, and receives the result through a local
HTTP callback. It never sees or stores your password, and no additional software
is needed.

## Requirements

- PowerShell 5.1 or later and an accessible default browser.
- An HTTPS Kelvin instance with the public Keycloak client `kelvin-client`,
  authorization-code login and PKCE enabled.
- A registered loopback redirect URI. Kelvin 5.2.0+ registers
  `http://localhost:38638/*` by default; only port **38638** is allowed by that
  default registration.
- Permission to listen on the local callback port. The browser must be able to
  reach the PowerShell host through that loopback address.

## Signing in

```powershell
Connect-KelvinAccount https://<my-instance>.kelvin.ai/ -Interactive
```

1. PoshKelvin starts a listener on `http://localhost:38638/`, then opens your
   default browser on the Keycloak authorization endpoint. If the browser
   cannot be opened, PoshKelvin prints the sign-in URL so you can open it
   yourself.
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
change Keycloak's allowlist. It is ignored for password login.
Remove the variable to restore the default:

```powershell
Remove-Item Env:\KELVIN_AUTH_REDIRECT_URI
```

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
  Native login eventually times out if no callback arrives.
- **"Cannot start the OAuth callback listener"**: another login or application
  may be using the port. Close that login or ask the administrator to register
  another redirect. On Windows, HTTP listener URL reservations may also require
  administrator configuration; do not run a privileged shell just to sign in.
- **"Unable to open the default browser"**: open the printed sign-in URL in a
  browser on the same machine; PoshKelvin keeps waiting for the callback.
- **WSL, SSH or remote shells**: the default browser must be reachable and its
  `localhost` callback must reach this PowerShell process. Check WSL localhost
  forwarding if the browser runs on Windows. A remote browser's loopback address
  normally refers to the wrong host; use a local PowerShell session instead.
- **"OAuth callback state ... does not match"**: no code was exchanged. Start a
  new login and do not reuse callback URLs from old tabs.
- **"OAuth authorization-code exchange failed"**: verify the client's redirect,
  authorization-code grant and PKCE settings with the administrator.
- **"Timed out after N seconds"**: sign in faster, or use a larger `-Timeout`.
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
