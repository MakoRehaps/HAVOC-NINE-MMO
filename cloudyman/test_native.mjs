// Real transport smoke test with a dummy UDP echo server.
// Tests native Cloudyman host discovery, code auth, WS upgrade, and bidirectional UDP.
// Does not launch or modify HAVOC 9; still requires live in-game multiplayer testing.
import net from "node:net";
import dgram from "node:dgram";
import crypto from "node:crypto";
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DIR = path.dirname(fileURLToPath(import.meta.url));
const NODE = process.execPath;
const ROOM = "ACDEFGHJKLMN2345";
const children = [];
const game = dgram.createSocket("udp4");
const listener = dgram.createSocket("udp4");
let done = false;
const fail = reason => finish(new Error(reason));
function finish(error) {
  if (done) return;
  done = true;
  for (const p of children) p.kill();
  game.close(); listener.close();
  if (error) { console.error("CLOUDYMAN SMOKE FAILED:", error.message); process.exitCode = 1; }
  else console.log("CLOUDYMAN SMOKE PASSED: host discovery + room authentication + UDP roundtrip");
}
async function tcpFree() {
  const server = net.createServer();
  await new Promise((resolve, reject) => server.once("error", reject).listen(0, "127.0.0.1", resolve));
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}
function child(name, script, env) {
  const p = spawn(NODE, [path.join(DIR, script)], { env: {...process.env, ...env}, cwd: path.resolve(DIR, ".."), stdio: ["ignore", "pipe", "pipe"] });
  children.push(p);
  p.stdout.on("data", data => { console.log(name, String(data).trim()); if (name === "client" && String(data).includes("RELAY VERIFIED.")) listener.send(Buffer.from("H9PING"), localPort, "127.0.0.1"); });
  p.stderr.on("data", data => console.error(name, String(data).trim()));
  p.on("exit", code => { if (!done) fail(name + " unexpectedly exited " + code); });
  return p;
}
const watchdog = setTimeout(() => fail("timeout without UDP roundtrip"), 12000);
watchdog.unref();
await new Promise(resolve => game.bind(0, "127.0.0.1", resolve));
const gamePort = game.address().port;
game.on("message", (data, peer) => game.send(Buffer.concat([Buffer.from("REPLY"), data]), peer.port, peer.address));
const hostPort = await tcpFree();
const reservation = dgram.createSocket("udp4");
await new Promise(resolve => reservation.bind(0, "127.0.0.1", resolve));
const localPort = reservation.address().port;
await new Promise(resolve => reservation.close(resolve));
await new Promise(resolve => listener.bind(0, "127.0.0.1", resolve));
listener.on("message", data => {
  if (String(data) === "REPLYH9PING") { clearTimeout(watchdog); finish(); }
});
child("host", "native_host.mjs", { CLOUDYMAN_GAME_PORT: String(gamePort), CLOUDYMAN_HTTP_PORT: String(hostPort), CLOUDYMAN_ROOM_CODE: ROOM });
let ready = false;
for (let i = 0; i < 60; i++) {
  try {
    const r = await fetch("http://127.0.0.1:" + hostPort + "/session", { signal: AbortSignal.timeout(250) });
    const v = await r.json();
    if (v.service === "cloudyman-native") { ready = true; break; }
  } catch {}
  await new Promise(resolve => setTimeout(resolve, 100));
}
if (!ready) fail("host did not answer session lookup");
if (!done) child("client", "native_client.mjs", { CLOUDYMAN_DOMAIN: "localhost:" + hostPort, CLOUDYMAN_LOCAL_PORT: String(localPort), CLOUDYMAN_ROOM_CODE: ROOM });
