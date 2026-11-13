// Native HAVOC 9 client sidecar. Xash console: connect 127.0.0.1:27016
// This process sends and receives unchanged UDP datagrams through Cloudyman WSS.
// No engine patches, no browser and no writes into the game tree.
import dgram from "node:dgram";
import { WebSocket } from "node:undici";

const port = Number(process.env.CLOUDYMAN_LOCAL_PORT || 27016);
const link = process.env.CLOUDYMAN_JOIN_LINK || "";
const probe = process.argv.includes("--probe");
const MAGIC = "CLOUDYMAN_NATIVE_1";
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error("Invalid CLOUDYMAN_LOCAL_PORT"); process.exit(2);
}
let remote;
try { remote = new URL(link); } catch { console.error("No valid join link."); process.exit(2); }
if (!["wss:", "ws:"].includes(remote.protocol) || remote.pathname !== "/native" || !remote.searchParams.get("key")) {
  console.error("Expected a Cloudyman native wss://hostname/native?key=... link."); process.exit(2);
}
if (remote.protocol === "ws:" && !["localhost", "127.0.0.1"].includes(remote.hostname)) {
  console.error("Unencrypted WebSocket is allowed only for localhost tests."); process.exit(2);
}
const udp = dgram.createSocket("udp4");
let ws, peer = null, ready = false, closed = false;
let packetsUp = 0, packetsDown = 0;
function connect() {
  ready = false;
  ws = new WebSocket(link);
  ws.binaryType = "arraybuffer";
  ws.addEventListener("open", () => console.log("Cloudyman TLS/WebSocket connected; verifying relay..."));
  ws.addEventListener("message", ev => {
    const msg = Buffer.from(ev.data);
    if (!ready) {
      if (msg.toString() !== MAGIC) { console.error("Wrong relay protocol"); ws.close(); return; }
      ready = true;
      console.log("RELAY VERIFIED. In HAVOC 9 console enter: connect 127.0.0.1:" + port);
      if (probe) { console.log("PROBE_OK"); closed = true; ws.close(); process.exit(0); }
      return;
    }
    if (msg.length && msg.length <= 8192 && peer) {
      udp.send(msg, peer.port, peer.address);
      packetsDown++;
    }
  });
  ws.addEventListener("error", ev => { console.error("Relay WebSocket error"); });
  ws.addEventListener("close", ev => {
    ready = false;
    console.error("Relay closed", ev.code);
    if (probe) process.exit(1);
    if (!closed) setTimeout(connect, 2000);
  });
}
if (!probe) {
  udp.on("message", (data, rinfo) => {
    if (rinfo.address !== "127.0.0.1") return;
    peer = { address: rinfo.address, port: rinfo.port };
    if (ready && ws.readyState === WebSocket.OPEN && data.length && data.length <= 8192) {
      ws.send(data);
      packetsUp++;
    }
  });
  udp.on("error", e => { console.error("UDP listener error:", e.message); process.exit(1); });
  udp.bind(port, "127.0.0.1", () => console.log("Game UDP listener: 127.0.0.1:" + port));
  setInterval(() => console.log("Native relay packets: up=" + packetsUp + ", down=" + packetsDown + ", connected=" + ready), 30000).unref();
}
connect();
process.on("SIGINT", () => { closed = true; try { ws.close(); } catch {} udp.close(); });
process.on("SIGTERM", () => { closed = true; try { ws.close(); } catch {} udp.close(); });
