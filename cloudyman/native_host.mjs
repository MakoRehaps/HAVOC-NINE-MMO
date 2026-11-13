// Standalone Cloudyman native Xash relay: WSS -> one isolated UDP socket per client.
// Never changes or replaces H9XASH networking, and is not a general-purpose UDP proxy.
import http from "node:http";
import dgram from "node:dgram";
import crypto from "node:crypto";
import { checkUpgrade, refuseUpgrade, acceptUpgrade, WebSocketConnection } from "../h9web/lib/websocket.js";

const port = Number(process.env.CLOUDYMAN_HTTP_PORT || 8090);
const gamePort = Number(process.env.CLOUDYMAN_GAME_PORT || 27015);
const maxClients = Number(process.env.CLOUDYMAN_MAX_CLIENTS || 32);
const key = (process.env.CLOUDYMAN_ROOM_CODE || "").toUpperCase();
const attempts = new Map();
if (![port, gamePort].every(p => Number.isInteger(p) && p >= 1 && p <= 65535)
    || !Number.isInteger(maxClients) || maxClients < 1 || maxClients > 128 || !/^[A-Z2-9]{12,20}$/.test(key)) {
  console.error("Invalid ports/client limit or missing CLOUDYMAN_ROOM_CODE (12-20 characters).");
  process.exit(2);
}
const sessions = new Set();
const counters = { accepted: 0, packetsUp: 0, packetsDown: 0, dropped: 0 };
const MAX_PACKET = 8192;
const STARTUP = Buffer.from("CLOUDYMAN_NATIVE_1");
function log(message) { console.log(new Date().toISOString(), message); }
function authenticate(req) {
  let request;
  try { request = new URL(req.url, "http://localhost"); } catch { return false; }
  if (request.pathname !== "/native") return false;
  const supplied = Buffer.from((request.searchParams.get("key") || "").toUpperCase());
  const expected = Buffer.from(key);
  return supplied.length === expected.length && crypto.timingSafeEqual(supplied, expected);
}
const server = http.createServer((req, res) => {
  if (req.method === "GET" && req.url === "/session") {
    res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    res.end(JSON.stringify({ service: "cloudyman-native", protocol: 1, game: "HAVOC-NINE", hosting: true }));
    return;
  }
  if (req.method === "GET" && req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    res.end(JSON.stringify({ service: "cloudyman-native", version: 1, sessions: sessions.size, ...counters }));
    return;
  }
  res.writeHead(404); res.end();
});
server.on("upgrade", (req, socket, head) => {
  const valid = checkUpgrade(req);
  if (!valid.ok) return refuseUpgrade(socket, valid.status, valid.headers);
  const ip = socket.remoteAddress || "unknown";
  let rate = attempts.get(ip) || { count: 0, first: Date.now() };
  if (Date.now() - rate.first > 60000) rate = { count: 0, first: Date.now() };
  if (rate.count >= 10) return refuseUpgrade(socket, 429);
  if (!authenticate(req)) { rate.count++; attempts.set(ip, rate); return refuseUpgrade(socket, 401); }
  attempts.delete(ip);
  if (sessions.size >= maxClients) return refuseUpgrade(socket, 503);
  // Only the locally configured game server receives datagrams.
  acceptUpgrade(socket, valid.key);
  const ws = new WebSocketConnection(socket, head, { maxMessage: MAX_PACKET, maxPendingBytes: 256 * 1024 });
  const udp = dgram.createSocket("udp4");
  const session = { ws, udp, lastActivity: Date.now(), windowStart: Date.now(), packetCount: 0 };
  sessions.add(session);
  counters.accepted++;
  udp.on("message", (packet, remote) => {
    if (remote.address !== "127.0.0.1" || remote.port !== gamePort) { counters.dropped++; return; }
    if (packet.length > MAX_PACKET) { counters.dropped++; return; }
    if (ws.send(packet)) { counters.packetsDown++; session.lastActivity = Date.now(); }
    else counters.dropped++;
  });
  udp.on("error", () => ws.terminate());
  udp.bind(0, "127.0.0.1");
  ws.on("message", (data, binary) => {
    if (!binary || !data.length || data.length > MAX_PACKET) { counters.dropped++; return; }
    const now = Date.now();
    if (now - session.windowStart >= 1000) { session.windowStart = now; session.packetCount = 0; }
    if (++session.packetCount > 250) { counters.dropped++; return; }
    udp.send(data, gamePort, "127.0.0.1", err => { if (err) counters.dropped++; });
    counters.packetsUp++;
    session.lastActivity = now;
  });
  ws.on("close", () => { sessions.delete(session); try { udp.close(); } catch {} });
  ws.send(STARTUP);
  log("client connected; active=" + sessions.size);
});
const timer = setInterval(() => {
  for (const [ip, rate] of attempts) if (Date.now() - rate.first > 120000) attempts.delete(ip);
  for (const s of sessions) {
    if (Date.now() - s.lastActivity > 180000) s.ws.close(1000, "idle");
    else s.ws.ping();
  }
}, 15000);
server.listen(port, "127.0.0.1", () => log("CLOUDYMAN native relay http://127.0.0.1:" + port + " -> UDP 127.0.0.1:" + gamePort));
function stop() { clearInterval(timer); for (const s of sessions) s.ws.terminate(); server.close(); }
process.on("SIGINT", stop);
process.on("SIGTERM", stop);
