# CLOUDYMAN — Native HAVOC-NINE Host / Join

Cloudyman is a **standalone sidecar** for the real Windows Xash3D game, not a browser game. It does **not** overwrite HAVOC 9.exe, mod files, maps, weapons, scripts, or engine networking. It starts the original H9 launcher(s) and bridges their unchanged UDP packets through WebSockets.

## Normal players: two buttons

1. Run `cloudyman/Cloudyman.exe` (build it with `cloudyman/READY_TEST.ps1`).
2. Choose **Localhost** (same-PC test) or **Domain** (remote friend with a Cloudflare hostname). Use the same selection on both PCs.
3. Host clicks **HOST GAME**. Cloudyman starts the real dedicated server if one is not already responding, starts the native host relay and starts a normal local client connected to the server. It displays a randomly generated **16-character room code**.
4. Friend enters the **host domain and room code**, then clicks **JOIN GAME**. Cloudyman requests `https://host.example.com/session` (or `http://localhost:8090/session`), checks the native protocol, authenticates its WebSocket, opens the original HAVOC 9 game and issues normal `+connect 127.0.0.1:27016` launch arguments. No browser or in-game console needed.
5. STOP closes only processes Cloudyman launched. Existing game systems remain unchanged.

**Localhost is for the same machine only.** Friends on other computers must choose Domain and use the host's actual DNS name.

## Domain setup

A normal Cloudflare HTTP Tunnel does not directly transport game UDP. Cloudyman operates its own native **UDP <-> authenticated WebSocket** sidecars, so ordinary Xash uses a local UDP socket while the internet leg travels through secure WSS.

The host must already have a **Cloudflare named tunnel** and a DNS hostname routing to **`http://127.0.0.1:8090`** (or the GUI's host relay port). Cloudyman starts `cloudflared tunnel run <name>`; it does not automatically create Cloudflare accounts, DNS routes, credentials, or a public tunnel. Node.js 24+ and cloudflared are required on the host; friends need Node.js 24+ but not cloudflared. Do not post room codes publicly.

Host bridge: `cloudyman/native_host.mjs` -> locally bound Xash UDP 27015. Each WSS client has a separate UDP socket (player identity preserved by destination source port). Client bridge: `cloudyman/native_client.mjs` -> local UDP 27016. Both operate separately from `h9web`'s browser WebAssembly relay; only the verified WSS frame implementation is reused.

## Build, diagnostics, test

From a checkout root in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\cloudyman\READY_TEST.ps1
```

The setup updates your checkout, runs PyInstaller, syntax checks the native Node sidecars and runs `node cloudyman/test_native.mjs`, a native relay smoke test with an isolated UDP echo server. **WebAssembly is not built by default**; optional `-BuildWebClient` retains the old browser project if wanted. Logs are in `%LOCALAPPDATA%\Cloudyman\logs`.

Successful smoke tests establish only local room lookup, code authentication, and UDP relay roundtrip. A real Xash join, high latency, reconnect and an external two-PC Cloudflare join still need verification on actual Windows clients. Cloudflare Access login pages or an incorrect ingress route will stop WSS joins.

## Notes / limits

- HTTPS URL is a **host discovery endpoint**, not a URL to paste into Xash's `connect` command. Cloudyman obtains the correct local UDP address automatically.
- Wrong room code -> rejected WebSocket. Invalid host or unavailable route -> lookup failed; check logs.
- The 16-character room code is an access secret. It has a much larger keyspace than a six-digit number. Rotate by restarting Host Game.
- The sidecar only forwards to the host's configured localhost game UDP address; it is **not an open UDP proxy**.
- If hosting an existing listen server, verify it responds to the local UDP A2S query. The dedicated launcher is used otherwise.
- Native game protocol compatibility has not been fully verified end-to-end. The command-line connect flags use the existing H9 launcher rather than a new engine hook.
