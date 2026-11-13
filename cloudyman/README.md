# CLOUDYMAN — HAVOC-NINE REAL HOST GUI

This folder controls existing components of **this repository**, not a replacement game or simulation.

- Actual dedicated server: `../H9XASH/h9xash_server.bat` / `HAVOC 9.exe`, default **UDP 27015**.
- Actual browser site, accounts, and authenticated WebSocket-to-UDP relay: `../h9web/bin/local-site.js`, default **HTTP 8090**.
- Actual browser Xash/WebAssembly client: `../havoc9.org/webclient/`.
- Outbound HTTPS/WebSocket exposure: existing Cloudflare named tunnel using `cloudflared tunnel run <name-or-uuid>`.

## Windows

Install Node.js **24 or newer**, Python 3 with Tkinter, and Cloudflare's `cloudflared`; ensure the existing tunnel is already authenticated. From the checkout:

```cmd
py -3 cloudyman\launcher.py
```

The GUI asks for your existing Cloudflare hostname and tunnel name; click START HOSTING. The **COPY JOIN LINK** button copies `https://<hostname>/webclient/`.

**Cloudflare public hostname route must already point to `http://localhost:8090`**, or to the local site port configured in the GUI. No new tunnel, DNS record, or credential is created by Cloudyman. Do not commit tunnel credentials.

The GUI writes settings/logs to `%LOCALAPPDATA%\Cloudyman\`. The site keeps accounts and secrets separately in `%LOCALAPPDATA%\h9web-local\`. The runner registers one local UDP server with the existing relay under reserved virtual address `198.51.100.20:<game port>`, targeting `127.0.0.1:<game port>`; this address is **not** an internet-facing public IP.

The existing `h9web` authenticated relay requires the player to sign in. The webclient also needs an assembled WebAssembly **stage with manifest.json**; `h9web/bin/local-site.js` looks in `webclient-build/stage` or the configured TSM checkout. Without that stage the PLAY page stays in preparation. Create the web build using this repo's existing build scripts.

For a Windows executable, run `build_windows.bat` and place the resulting `Cloudyman.exe` **inside this cloudyman folder** before running. The exe only bundles the control GUI: the repository, engine, Node.js, existing web stage and cloudflared are still required.

## Constraints and test notes

A normal Cloudflare HTTP Tunnel does **not** expose arbitrary UDP for native Xash desktop clients. Browser players use HTTPS WebSockets into the H9 relay, which then talks to local UDP 27015. Native clients require a separately reachable UDP server (or a separate game-compatible transport).

Status reports a local HTTP check and a UDP A2S query, **not** proof that public Cloudflare DNS/authentication/firewall routing works. A tunnel process remaining alive is not a verified end-to-end join.

No Windows execution or live external two-player join has been verified in this environment. The standalone old `cloudyman/server.py` and `client.html` demo have been retired; they must not be used for HAVOC-NINE hosting.
