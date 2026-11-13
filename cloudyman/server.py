import asyncio, json, math, random, sys, time
from pathlib import Path
from aiohttp import web, WSMsgType

PAGE = Path(getattr(sys, '_MEIPASS', Path(__file__).parent)) / 'client.html'

class World:
    def __init__(self):
        self.players={}; self.clients={}; self.next_id=0; self.started=time.time()
    async def home(self, request):
        return web.FileResponse(PAGE)
    async def status(self, request):
        return web.json_response({'players':len(self.players),'online':True,'uptime':int(time.time()-self.started)})
    async def send_state(self):
        payload=json.dumps({'type':'state','players':list(self.players.values())})
        for ws in list(self.clients.values()):
            if not ws.closed:
                try: await ws.send_str(payload)
                except ConnectionError: pass
    async def websocket(self, request):
        ws=web.WebSocketResponse(heartbeat=20,max_msg_size=2048)
        await ws.prepare(request)
        self.next_id+=1
        pid=str(self.next_id)
        self.clients[pid]=ws
        self.players[pid]={'id':pid,'name':'Player '+pid,'x':random.randint(50,750),'y':random.randint(50,450),'color':random.choice(['#7de5f7','#f8b866','#86eea6','#de9af4'])}
        await ws.send_json({'type':'welcome','id':pid})
        await self.send_state()
        last=0.0
        try:
            async for msg in ws:
                if msg.type!=WSMsgType.TEXT: continue
                try: data=json.loads(msg.data)
                except (ValueError,TypeError): continue
                if not isinstance(data,dict): continue
                if data.get('type')=='name':
                    self.players[pid]['name']=str(data.get('name') or 'Player')[:20]
                    await self.send_state()
                if data.get('type')=='move' and time.monotonic()-last>=0.025:
                    last=time.monotonic()
                    try:
                        dx=float(data.get('dx',0)); dy=float(data.get('dy',0))
                        if not math.isfinite(dx) or not math.isfinite(dy): continue
                    except (TypeError,ValueError): continue
                    norm=max(1,math.hypot(dx,dy)); p=self.players[pid]
                    p['x']=max(16,min(784,p['x']+5*dx/norm))
                    p['y']=max(16,min(484,p['y']+5*dy/norm))
                    await self.send_state()
        finally:
            self.clients.pop(pid,None);self.players.pop(pid,None)
            await self.send_state()
        return ws

def create_app():
    w=World(); app=web.Application(client_max_size=2048)
    app.add_routes([web.get('/',w.home),web.get('/status',w.status),web.get('/ws',w.websocket)])
    return app

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8080)
    web.run_app(create_app(),host='127.0.0.1',port=p.parse_args().port,print=None)
