"""Cloudyman: Windows GUI for the *actual* HAVOC-NINE dedicated server and browser client."""
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent.parent
CONFIG = Path(os.getenv("LOCALAPPDATA") or Path.home()) / "Cloudyman" / "settings.json"
LOGS = CONFIG.parent / "logs"
CREATION_FLAGS = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0) | getattr(subprocess, "CREATE_NO_WINDOW", 0)

def find_repo():
    return ROOT if (ROOT / "H9XASH" / "h9xash_server.bat").is_file() else None

def locate(program):
    return shutil.which(program) or (str(Path(program).resolve()) if Path(program).is_file() else None)

def check_server(port):
    """A2S_INFO, distinct from browser relay socket count."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(.35)
            sock.sendto(b"\xff\xff\xff\xffTSource Engine Query\x00", ("127.0.0.1", port))
            response, _ = sock.recvfrom(4096)
        if response[:5] == b"\xff\xff\xff\xff\x49":
            body = response[6:]
            for _ in range(4):
                i = body.find(b"\x00")
                if i < 0: return "Responding"
                body = body[i + 1:]
            if len(body) >= 4:
                return str(body[2]) + "/" + str(body[3])
            return "Responding"
        if response[:5] == b"\xff\xff\xff\xff\x6d":
            body = response[5:]
            for _ in range(5):
                i=body.find(b"\x00")
                if i<0:return "Responding"
                body=body[i+1:]
            return str(body[0]) + "/" + str(body[1]) if len(body)>1 else "Responding"
        return "Responding"
    except OSError:
        return "Not responding"

class Cloudyman:
    def __init__(self, root):
        self.root=root
        root.title("CLOUDYMAN — HAVOC-NINE HOST")
        root.geometry("660x540")
        try: saved=json.loads(CONFIG.read_text(encoding="utf-8"))
        except (OSError, ValueError): saved={}
        self.domain=tk.StringVar(value=saved.get("domain",""))
        self.tunnel=tk.StringVar(value=saved.get("tunnel",""))
        self.cfexe=tk.StringVar(value=saved.get("cfexe","cloudflared"))
        self.port=tk.StringVar(value=str(saved.get("port",27015)))
        self.webport=tk.StringVar(value=str(saved.get("webport",8090)))
        self.status=tk.StringVar(value="OFFLINE")
        self.site_status=tk.StringVar(value="Website: stopped")
        self.game_status=tk.StringVar(value="Game server: stopped")
        self.player_status=tk.StringVar(value="Players: —")
        self.note=tk.StringVar(value="Uses the actual H9XASH and h9web components in this checkout.")
        self.procs={}
        self.logs={}
        frame=ttk.Frame(root,padding=20);frame.pack(fill="both",expand=True)
        ttk.Label(frame,text="CLOUDYMAN",font=("Segoe UI",24,"bold")).pack(anchor="w")
        ttk.Label(frame,text="HAVOC-NINE  |  REAL SERVER HOSTING",font=("Segoe UI",11)).pack(anchor="w",pady=(0,16))
        for label,var in [("Cloudflare hostname",self.domain),("Existing tunnel name / UUID",self.tunnel),("cloudflared executable",self.cfexe),("Game UDP port",self.port),("Website HTTP port",self.webport)]:
            line=ttk.Frame(frame);line.pack(fill="x",pady=4)
            ttk.Label(line,text=label,width=29).pack(side="left")
            ttk.Entry(line,textvariable=var).pack(side="left",fill="x",expand=True)
        buttons=ttk.Frame(frame);buttons.pack(fill="x",pady=15)
        ttk.Button(buttons,text="START HOSTING",command=self.start).pack(side="left",ipadx=12,ipady=12)
        ttk.Button(buttons,text="STOP ALL",command=self.stop).pack(side="left",padx=8,ipadx=12,ipady=12)
        ttk.Button(buttons,text="COPY JOIN LINK",command=self.copy).pack(side="right",ipady=12)
        for variable in (self.status,self.game_status,self.site_status,self.player_status,self.note):
            ttk.Label(frame,textvariable=variable,wraplength=590).pack(anchor="w",pady=4)
        ttk.Label(frame,text="Requires Node.js 24+, existing cloudflared named tunnel credentials, and H9XASH.\nCloudflare public hostname must route to http://localhost:8090 (or your HTTP port).\nAn HTTPS tunnel alone does NOT publish native Xash UDP connections.",wraplength=585).pack(anchor="w",pady=14)
        root.protocol("WM_DELETE_WINDOW",self.close)
        self.poll()
    def origin(self):
        return "https://" + self.domain.get().strip().removeprefix("https://").rstrip("/")
    def copy(self):
        if not self.domain.get().strip():return
        link=self.origin()+"/webclient/"
        self.root.clipboard_clear();self.root.clipboard_append(link)
        self.note.set("Copied browser client: "+link)
    def launch(self,key,cmd,cwd,env):
        log=open(LOGS/(key+".log"),"ab",buffering=0)
        try:
            p=subprocess.Popen(cmd,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=CREATION_FLAGS)
        except BaseException:
            log.close()
            raise
        self.logs[key]=log;self.procs[key]=p
    def start(self):
        if any(p.poll() is None for p in self.procs.values()):
            self.note.set("Already running. Stop before changing settings.")
            return
        if not find_repo():
            messagebox.showerror("Repository missing","Run this launcher from HAVOC-NINE-MMO/cloudyman/ inside the full checkout.")
            return
        domain=self.domain.get().strip().removeprefix("https://").rstrip("/")
        if not re.fullmatch(r"[a-z0-9-]+(?:\.[a-z0-9-]+)+",domain,re.I):
            messagebox.showerror("Invalid hostname","Enter your existing Cloudflare DNS hostname (no https://).")
            return
        try:
            port=int(self.port.get());webport=int(self.webport.get())
            if not (1024<=port<=65535 and 1024<=webport<=65535 and port!=webport):raise ValueError()
        except ValueError:
            messagebox.showerror("Ports","Ports must be distinct numbers between 1024 and 65535.")
            return
        cf=locate(self.cfexe.get().strip())
        node=locate("node")
        if not cf or not node:
            messagebox.showerror("Missing dependency",("cloudflared" if not cf else "Node.js")+" not found in PATH. Install it or select cloudflared.exe.")
            return
        if not self.tunnel.get().strip():
            messagebox.showerror("Existing tunnel","Enter your existing named Cloudflare tunnel or UUID.")
            return
        if not (ROOT/"H9XASH"/"HAVOC 9.exe").exists():
            messagebox.showerror("Missing engine","H9XASH/HAVOC 9.exe is missing.")
            return
        LOGS.mkdir(parents=True,exist_ok=True)
        CONFIG.parent.mkdir(parents=True,exist_ok=True)
        CONFIG.write_text(json.dumps({"domain":domain,"tunnel":self.tunnel.get().strip(),"cfexe":self.cfexe.get().strip(),"port":port,"webport":webport},indent=2),encoding="utf-8")
        env=os.environ.copy()
        env["H9WEB_PUBLIC_ORIGIN"]="https://"+domain
        env["H9WEB_LOCAL_GAME_PORT"]=str(port)
        # These are regular child processes, not demo game services.
        try:
            self.launch("game",["cmd.exe","/d","/c",str(ROOT/"H9XASH"/"h9xash_server.bat"),"-port",str(port)],ROOT/"H9XASH",env)
            self.launch("website",[node,str(ROOT/"h9web"/"bin"/"local-site.js"),"--port",str(webport)],ROOT,env)
            self.launch("cloudflare",[cf,"tunnel","run",self.tunnel.get().strip()],ROOT,env)
        except OSError as e:
            self.stop()
            messagebox.showerror("Launch failed",str(e))
            return
        self.status.set("STARTING")
        self.note.set("Logs: "+str(LOGS))
    def stop(self):
        # Windows process tree handling: cmd.exe's server child must be stopped too.
        for name in ("cloudflare","website","game"):
            p=self.procs.get(name)
            if p and p.poll() is None:
                try:
                    if os.name=="nt":subprocess.run(["taskkill","/PID",str(p.pid),"/T","/F"],capture_output=True,timeout=8,creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
                    else:p.terminate()
                except (OSError,subprocess.SubprocessError):pass
        for file in self.logs.values():
            try:file.close()
            except OSError:pass
        self.logs.clear();self.procs.clear()
        self.status.set("OFFLINE");self.game_status.set("Game server: stopped");self.site_status.set("Website: stopped");self.player_status.set("Players: —")
    def poll(self):
        if self.procs:
            failures=[name for name,p in self.procs.items() if p.poll() is not None]
            self.status.set("ERROR — "+", ".join(failures)+" stopped; check logs" if failures else "HOSTING (check public DNS separately)")
            try:
                with urlopen("http://127.0.0.1:"+self.webport.get()+"/",timeout=.5) as resp:
                    self.site_status.set("Website: local HTTP "+str(resp.status))
            except Exception:self.site_status.set("Website: no local HTTP response")
            game=check_server(int(self.port.get()))
            self.game_status.set("Game server UDP: "+game)
            self.player_status.set("Players: "+game if "/" in game else "Players: —")
        self.root.after(2000,self.poll)
    def close(self):
        self.stop();self.root.destroy()

if __name__=="__main__":
    root=tk.Tk()
    Cloudyman(root)
    root.mainloop()
