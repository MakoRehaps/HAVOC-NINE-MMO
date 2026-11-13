"""HAVOC-NINE Cloudyman Windows GUI. Runs a local browser test and existing cloudflared named tunnel."""
import json
import os
import shutil
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from tkinter import ttk, messagebox
from urllib.request import urlopen

BASE=Path(getattr(sys,'_MEIPASS',Path(__file__).parent))
CONFIG=Path(os.environ.get('APPDATA',str(Path.home())))/'HAVOC-NINE'/'cloudyman.json'
FLAGS=getattr(subprocess,'CREATE_NO_WINDOW',0)

class App:
    def __init__(self,root):
        self.root=root;root.title('HAVOC-NINE / Cloudyman');root.geometry('640x490')
        try: cfg=json.loads(CONFIG.read_text(encoding='utf-8'))
        except (OSError,ValueError):cfg={}
        self.host=tk.StringVar(value=cfg.get('host','play.example.com'))
        self.tunnel=tk.StringVar(value=cfg.get('tunnel','havoc-nine'))
        self.port=tk.StringVar(value=str(cfg.get('port',8080)))
        self.exe=tk.StringVar(value=cfg.get('exe','cloudflared'))
        self.status=tk.StringVar(value='Stopped');self.players=tk.StringVar(value='Players: 0')
        self.info=tk.StringVar(value='Uses your existing Cloudflare tunnel — no new domain.')
        self.server_proc=None;self.tunnel_proc=None
        f=ttk.Frame(root,padding=20);f.pack(fill='both',expand=True)
        ttk.Label(f,text='CLOUDYMAN',font=('Segoe UI',24,'bold')).pack(anchor='w')
        ttk.Label(f,text='HAVOC-NINE browser multiplayer testing').pack(anchor='w',pady=(0,14))
        for label,var in [('Existing hostname',self.host),('Existing named tunnel',self.tunnel),('Test server port',self.port),('cloudflared executable',self.exe)]:
            row=ttk.Frame(f);row.pack(fill='x',pady=5)
            ttk.Label(row,text=label,width=27).pack(side='left')
            ttk.Entry(row,textvariable=var).pack(side='left',fill='x',expand=True)
        bar=ttk.Frame(f);bar.pack(fill='x',pady=17)
        ttk.Button(bar,text='START HOSTING',command=self.start).pack(side='left',ipadx=10,ipady=10)
        ttk.Button(bar,text='STOP',command=self.stop).pack(side='left',padx=8,ipadx=10,ipady=10)
        ttk.Button(bar,text='COPY JOIN LINK',command=self.copy).pack(side='right',ipady=10)
        ttk.Label(f,textvariable=self.status,font=('Segoe UI',15,'bold')).pack(anchor='w')
        ttk.Label(f,textvariable=self.players).pack(anchor='w',pady=8)
        ttk.Label(f,textvariable=self.info,wraplength=560).pack(anchor='w')
        ttk.Label(f,text='Your existing Cloudflare public hostname must forward to localhost on this port.\nLocal status does not prove external tunnel connectivity.',wraplength=560).pack(anchor='w',pady=18)
        root.protocol('WM_DELETE_WINDOW',self.close);self.poll()

    def link(self):
        return 'https://'+self.host.get().strip().removeprefix('https://').rstrip('/')+'/'
    def copy(self):
        self.root.clipboard_clear();self.root.clipboard_append(self.link())
        self.info.set('Copied: '+self.link())
    def start(self):
        if self.server_proc and self.server_proc.poll() is None:return
        try:
            port=int(self.port.get())
            if port<1024 or port>65535 or '.' not in self.host.get() or not self.tunnel.get().strip():raise ValueError()
            CONFIG.parent.mkdir(parents=True,exist_ok=True)
            CONFIG.write_text(json.dumps({'host':self.host.get(),'tunnel':self.tunnel.get(),'port':port,'exe':self.exe.get()},indent=2),encoding='utf-8')
        except (ValueError,OSError):
            messagebox.showerror('Configuration','Enter a valid hostname, tunnel name and port (1024-65535).');return
        exe=self.exe.get().strip()
        if not (shutil.which(exe) or Path(exe).is_file()):
            messagebox.showerror('Cloudflare client missing','Install cloudflared or enter its full exe path.');return
        cmd=[sys.executable,'--server','--port',str(port)] if getattr(sys,'frozen',False) else [sys.executable,str(BASE/'server.py'),'--port',str(port)]
        try:
            self.server_proc=subprocess.Popen(cmd,creationflags=FLAGS,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            self.tunnel_proc=subprocess.Popen([exe,'tunnel','run',self.tunnel.get().strip()],creationflags=FLAGS,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        except OSError as e:
            self.stop();messagebox.showerror('Start error',str(e));return
        self.status.set('Starting server and tunnel…')
    def stop(self):
        for p in (self.tunnel_proc,self.server_proc):
            if p and p.poll() is None:
                p.terminate()
                try:p.wait(timeout=3)
                except subprocess.TimeoutExpired:p.kill()
        self.server_proc=None;self.tunnel_proc=None
        self.status.set('Stopped');self.players.set('Players: 0')
    def poll(self):
        if self.server_proc:
            if self.server_proc.poll() is not None:
                self.status.set('ERROR: local server stopped')
            elif self.tunnel_proc and self.tunnel_proc.poll() is not None:
                self.status.set('ERROR: cloudflared stopped');self.info.set('Check tunnel credentials and existing config.')
            else:
                try:
                    with urlopen('http://127.0.0.1:'+self.port.get()+'/status',timeout=.4) as r:data=json.load(r)
                    self.status.set('LOCAL SERVER ONLINE')
                    self.players.set('Players: '+str(data['players']))
                    self.info.set('Join link: '+self.link()+' (public reachability unverified)')
                except Exception:self.status.set('Starting local server…')
        self.root.after(1500,self.poll)
    def close(self):self.stop();self.root.destroy()

if __name__=='__main__':
    if '--server' in sys.argv:
        from aiohttp import web
        from server import create_app
        i=sys.argv.index('--port')
        web.run_app(create_app(),host='127.0.0.1',port=int(sys.argv[i+1]),print=None)
    else:
        root=tk.Tk();App(root);root.mainloop()
