"""Cloudyman native HAVOC-NINE host/join GUI. Sidecars only: never edits game assets."""
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
from urllib.request import urlopen

ROOT = Path(sys.executable).resolve().parent.parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent.parent
BASE = Path(os.getenv("LOCALAPPDATA") or Path.home()) / "Cloudyman"
CONFIG = BASE / "settings.json"
LOGS = BASE / "logs"
FLAGS = getattr(subprocess, "CREATE_NO_WINDOW", 0)
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

def find(exe):
    if Path(exe).is_file(): return str(Path(exe).resolve())
    return shutil.which(exe)

def a2s(port):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(.3)
            sock.sendto(b"\xff\xff\xff\xffTSource Engine Query\x00", ("127.0.0.1", port))
            data, _ = sock.recvfrom(4096)
        return len(data) >= 5 and data[:4] == b"\xff\xff\xff\xff"
    except OSError:
        return False

class Cloudyman:
    def __init__(self, root):
        self.root = root
        root.title("CLOUDYMAN | HAVOC-NINE NATIVE MULTIPLAYER")
        root.geometry("720x650")
        try: saved = json.loads(CONFIG.read_text(encoding="utf-8"))
        except (OSError, ValueError): saved = {}
        self.mode = tk.StringVar(value="localhost")
        self.domain = tk.StringVar(value=saved.get("domain", ""))
        self.tunnel = tk.StringVar(value=saved.get("tunnel", ""))
        cfdefault = ROOT / "cloudyman" / "tools" / "cloudflared.exe"
        self.cloudflared = tk.StringVar(value=saved.get("cloudflared", str(cfdefault) if cfdefault.is_file() else "cloudflared"))
        self.code = tk.StringVar(value="")
        self.gameport = tk.StringVar(value=str(saved.get("gameport", 27015)))
        self.relayport = tk.StringVar(value=str(saved.get("relayport", 8090)))
        self.localport = tk.StringVar(value=str(saved.get("localport", 27016)))
        self.state = tk.StringVar(value="Stopped")
        self.instructions = tk.StringVar(value="Host: choose Localhost or Domain, then click HOST GAME. Join: enter a host and room code.")
        self.procs = {}
        self.handles = {}
        self.join_auto_started = False
        frame = ttk.Frame(root, padding=20)
        frame.pack(fill="both", expand=True)
        ttk.Label(frame, text="CLOUDYMAN", font=("Segoe UI", 23, "bold")).pack(anchor="w")
        ttk.Label(frame, text="Native HAVOC-NINE multiplayer — no browser or WebAssembly required").pack(anchor="w", pady=(0, 12))
        modes = ttk.Frame(frame); modes.pack(fill="x", pady=5)
        ttk.Label(modes, text="Connection:").pack(side="left")
        ttk.Radiobutton(modes, text="Localhost", variable=self.mode, value="localhost").pack(side="left", padx=12)
        ttk.Radiobutton(modes, text="Domain / Cloudflare", variable=self.mode, value="domain").pack(side="left", padx=12)
        for text, var in (
            ("Host domain (e.g. game.example.com)", self.domain),
            ("Existing Cloudflare tunnel name / UUID", self.tunnel),
            ("cloudflared.exe", self.cloudflared),
            ("Room code", self.code),
            ("Native game UDP port", self.gameport),
            ("Host relay HTTP port", self.relayport),
            ("Joining PC local UDP port", self.localport),
        ):
            line = ttk.Frame(frame); line.pack(fill="x", pady=3)
            ttk.Label(line, text=text, width=35).pack(side="left")
            ttk.Entry(line, textvariable=var).pack(side="left", fill="x", expand=True)
        bar = ttk.Frame(frame); bar.pack(fill="x", pady=16)
        ttk.Button(bar, text="HOST GAME", command=self.host).pack(side="left", ipadx=8, ipady=9)
        ttk.Button(bar, text="JOIN GAME", command=self.join).pack(side="left", padx=7, ipadx=8, ipady=9)
        ttk.Button(bar, text="COPY CODE", command=self.copy_code).pack(side="left", padx=7)
        ttk.Button(bar, text="STOP", command=self.stop).pack(side="right", ipadx=7, ipady=9)
        ttk.Label(frame, textvariable=self.state, font=("Segoe UI", 12, "bold")).pack(anchor="w", pady=8)
        ttk.Label(frame, textvariable=self.instructions, wraplength=650).pack(anchor="w", pady=8)
        ttk.Label(frame, text="Domain mode requires an existing Cloudflare tunnel hostname routed to http://127.0.0.1:8090.\nA running tunnel alone is not proof of multiplayer connectivity.\nHost gives friends the domain and room code; they enter both into JOIN GAME.\nLogs are saved in %LOCALAPPDATA%\\Cloudyman\\logs.", wraplength=650).pack(anchor="w", pady=8)
        root.protocol("WM_DELETE_WINDOW", self.close)
        root.after(1500, self.poll)

    def ports(self):
        a, b, c = int(self.gameport.get()), int(self.relayport.get()), int(self.localport.get())
        if any(n < 1024 or n > 65535 for n in (a,b,c)) or len({a,b,c}) != 3:
            raise ValueError("Ports must be distinct, in the range 1024–65535.")
        return a, b, c

    def mode_host(self):
        if self.mode.get() == "localhost": return "localhost:" + self.relayport.get()
        domain = self.domain.get().strip().removeprefix("https://").removeprefix("wss://").rstrip("/")
        if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", domain):
            raise ValueError("Enter a hostname such as game.example.com.")
        return domain

    def save(self):
        BASE.mkdir(parents=True, exist_ok=True)
        CONFIG.write_text(json.dumps({
            "domain": self.domain.get(), "tunnel": self.tunnel.get(),
            "cloudflared": self.cloudflared.get(), "gameport": int(self.gameport.get()),
            "relayport": int(self.relayport.get()), "localport": int(self.localport.get())
        }, indent=2), encoding="utf-8")

    def spawn(self, name, cmd, cwd, env):
        LOGS.mkdir(parents=True, exist_ok=True)
        f = open(LOGS / (name + ".log"), "wb", buffering=0)
        try:
            p = subprocess.Popen(cmd, cwd=str(cwd), env=env, stdout=f, stderr=subprocess.STDOUT, creationflags=FLAGS)
        except Exception:
            f.close()
            raise
        self.handles[name] = f
        self.procs[name] = p

    def prerequisites(self):
        node = find("node")
        if not node: raise ValueError("Node.js 24+ is missing.")
        if not (ROOT / "H9XASH" / "HAVOC 9.exe").is_file():
            raise ValueError("HAVOC 9.exe is missing from H9XASH.")
        for name in ("native_host.mjs", "native_client.mjs"):
            if not (ROOT / "cloudyman" / name).is_file(): raise ValueError("Missing cloudyman/" + name)
        return node

    def host(self):
        try:
            if self.procs: raise ValueError("Stop the current session first.")
            node = self.prerequisites()
            gp, rp, _ = self.ports()
            domain = self.mode_host()
            cf = None
            if self.mode.get() == "domain":
                cf = find(self.cloudflared.get().strip())
                if not cf: raise ValueError("Cannot find cloudflared.exe.")
                if not self.tunnel.get().strip(): raise ValueError("Enter the existing Cloudflare tunnel name.")
            self.code.set("".join(secrets.choice(ALPHABET) for _ in range(16)))
            self.save()
            env = os.environ.copy()
            env["CLOUDYMAN_ROOM_CODE"] = self.code.get()
            env["CLOUDYMAN_GAME_PORT"] = str(gp)
            env["CLOUDYMAN_HTTP_PORT"] = str(rp)
            if not a2s(gp):
                self.spawn("game", ["cmd.exe", "/d", "/c", str(ROOT / "H9XASH" / "h9xash_server.bat"), "-port", str(gp)], ROOT / "H9XASH", env)
            self.spawn("relay", [node, str(ROOT / "cloudyman" / "native_host.mjs")], ROOT, env)
            if cf:
                self.spawn("cloudflare", [cf, "tunnel", "run", self.tunnel.get().strip()], ROOT, env)
            self.state.set("HOST STARTING — local game/relay checks pending")
            self.instructions.set("Give your friend DOMAIN: " + domain + "   CODE: " + self.code.get() + ". Their Cloudyman JOIN GAME will connect to the native game. No browser needed.")
        except Exception as exc:
            self.stop()
            messagebox.showerror("Cannot host", str(exc))

    def join(self):
        try:
            if self.procs: raise ValueError("Stop the current session first.")
            node = self.prerequisites()
            _, _, lp = self.ports()
            domain = self.mode_host()
            code = self.code.get().strip().upper().replace("-", "").replace(" ", "")
            if not re.fullmatch(r"[A-Z2-9]{12,20}", code): raise ValueError("Enter the 12–20 character code from the host.")
            self.save()
            env = os.environ.copy()
            env["CLOUDYMAN_DOMAIN"] = domain
            env["CLOUDYMAN_ROOM_CODE"] = code
            env["CLOUDYMAN_LOCAL_PORT"] = str(lp)
            self.join_auto_started = False
            self.spawn("join", [node, str(ROOT / "cloudyman" / "native_client.mjs")], ROOT, env)
            self.state.set("JOINING — looking up " + domain)
            self.instructions.set("Cloudyman will automatically open HAVOC 9 and connect when the relay is verified. No game console commands needed.")
        except Exception as exc:
            self.stop()
            messagebox.showerror("Cannot join", str(exc))

    def copy_code(self):
        if self.code.get():
            self.root.clipboard_clear()
            self.root.clipboard_append(self.code.get())
            self.root.update()

    def stop(self):
        for name, p in list(self.procs.items()):
            if p.poll() is None:
                try:
                    subprocess.run(["taskkill", "/PID", str(p.pid), "/T", "/F"], capture_output=True, timeout=8, creationflags=FLAGS)
                except (OSError, subprocess.SubprocessError): pass
        self.procs.clear()
        self.join_auto_started = False
        for f in self.handles.values():
            try: f.close()
            except OSError: pass
        self.handles.clear()
        self.state.set("Stopped")

    def poll(self):
        if self.procs:
            failed = [name for name, p in self.procs.items() if p.poll() is not None]
            if failed: self.state.set("Stopped unexpectedly: " + ", ".join(failed) + " — check logs")
            elif "relay" in self.procs:
                try:
                    with urlopen("http://127.0.0.1:" + self.relayport.get() + "/health", timeout=.5) as response:
                        info = json.load(response)
                    game = a2s(int(self.gameport.get()))
                    self.state.set("Local relay: OK | Game UDP: " + ("replying" if game else "no A2S reply") + " | Clients: " + str(info.get("sessions", 0)) + " — external join not verified")
                except Exception:
                    self.state.set("Relay starting or unavailable — check logs")
            elif "join" in self.procs:
                try:
                    trace = (LOGS / "join.log").read_text(encoding="utf-8", errors="replace")
                    if "RELAY VERIFIED." in trace and not self.join_auto_started:
                        self.join_auto_started = True
                        _, _, joinport = self.ports()
                        # Invoke the game's existing launcher. It maintains game networking
                        # config and uses ordinary Xash +connect, without replacing anything.
                        self.spawn("clientgame", ["cmd.exe", "/d", "/c",
                            str(ROOT / "H9XASH" / "h9xash.bat"),
                            "+connect", "127.0.0.1:" + str(joinport)], ROOT / "H9XASH", os.environ.copy())
                        self.state.set("RELAY VERIFIED — launching HAVOC 9")
                        self.instructions.set("Connected to Cloudyman host. Launching the native game into the room.")
                    elif "Host lookup failed:" in trace:
                        self.state.set("HOST LOOKUP FAILED — check domain and tunnel route")
                    elif "Relay closed" in trace and "RELAY VERIFIED." not in trace:
                        self.state.set("RELAY AUTH FAILED — check room code")
                    elif not self.join_auto_started:
                        self.state.set("JOINING — verifying Cloudyman host and room code")
                    else:
                        self.state.set("HAVOC 9 started through native relay — game join not yet confirmed")
                except (OSError, ValueError) as exc:
                    self.state.set("Joining — " + str(exc))
        self.root.after(1500, self.poll)

    def close(self):
        self.stop()
        self.root.destroy()

if __name__ == "__main__":
    app = tk.Tk()
    Cloudyman(app)
    app.mainloop()
