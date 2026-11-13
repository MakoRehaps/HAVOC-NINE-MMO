# Cloudyman — HAVOC-NINE browser test GUI

Windows one-click launcher for an existing Cloudflare named tunnel. Browser clients use HTTPS + WebSockets; no port forwarding or new domain setup.

## Run from source
1. Install Python 3.11+, `cloudflared`, and `pip install -r cloudyman/requirements.txt`.
2. From this folder run `python launcher.py`.
3. Enter the existing Cloudflare hostname and tunnel name, then press START.
4. Share the HTTPS join link.

Your existing tunnel's public-hostname route must target `http://localhost:8080` (or the port selected in the GUI). Cloudyman does not create routes or manage credentials.

## Compile Windows GUI
Double-click `build_windows.bat`. The output is `dist/Cloudyman.exe`. Requires Windows Python with Tcl/Tk. No compiled exe is committed. Build not verified on Windows here.

## Limits
Browser sandbox for multiplayer joining, not the HAVOC-NINE game engine. Public tunnel reachability isn't established by local server status. No authentication or persistence; keep this a private supervised test. Do not publish tunnel credentials or tokens. Cloudflare WebSocket transport does not provide arbitrary UDP tunneling.