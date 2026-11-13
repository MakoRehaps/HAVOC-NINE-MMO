#!/usr/bin/env node
// local-site: the whole site on this PC, to try it: the pages, the accounts, the modules (the forum)
// and the web client, on one origin (http://127.0.0.1:8090), from this checkout. It sets itself up
// at every start:
//   * a folder of its own outside the checkout: %LOCALAPPDATA%\h9web-local on Windows,
//     ~/.h9web-local elsewhere, or H9WEB_LOCAL. It holds the accounts database and the secrets of
//     this PC's copy (accounts made here stay here), config.json, written fresh each start, and
//     servers.json, made once (an empty list) and kept, so a LAN server put in it stays;
//   * webclient\ in that folder: the site's web client page files with the package's
//     manifest.json and preload.json, copied fresh each start (h9web serves folders, not single
//     files);
//   * every module in modules\ that has an index.js (H9WEB_MODULES=a,b names them instead).
// The site's pages are served from the checkout as they are, so an edit to one shows on a reload;
// an edit to the web client's page files shows after a restart.
//
//   node bin/local-site.js [--port 8090] [--stage <folder>] [--files <folder>] [--open]
//
// The web client package (make_webclient_game.py's output) is, in order: --stage, H9WEB_STAGE,
// webclient-build\stage in the checkout, or in TSM_ROOT from the checkout's buildpaths.ini (the git
// copy names TSM there). Without one, PLAY says the client is in preparation. The downloads' file
// index, /downloads/files/, lists a packages folder read-only, as the VPS lists its own: --files,
// H9WEB_FILES, or dist\ in the checkout (stage-h9xash.ps1's and make-vps-package.ps1's output);
// without one it is an empty index. --open opens the site in the default browser. Ctrl+C stops it.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const HOME = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ROOT = path.resolve(HOME, "..");
const SITE = path.join(ROOT, "havoc9.org");

function fail(message) {
  console.error("local-site: " + message);
  process.exit(1);
}

const args = process.argv.slice(2);
function option(name) {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
}

const port = Number(option("--port") || process.env.H9WEB_PORT || 8090);
if (!Number.isInteger(port) || port < 1 || port > 65535) fail("--port must be a port number");
if (!fs.existsSync(path.join(SITE, "index.html"))) fail("no site at " + SITE);

const LOCAL = path.resolve(
  process.env.H9WEB_LOCAL ||
    (process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "h9web-local") : path.join(os.homedir(), ".h9web-local")),
);
if (LOCAL === ROOT || LOCAL.startsWith(ROOT + path.sep)) fail(LOCAL + " is inside the checkout: its accounts and secrets must stay out of git");
fs.mkdirSync(LOCAL, { recursive: true });

// TSM_ROOT from the checkout's buildpaths.ini, when it has one
function tsmRoot() {
  const ini = path.join(ROOT, "buildpaths.ini");
  if (!fs.existsSync(ini)) return null;
  const m = fs.readFileSync(ini, "utf8").match(/^\s*TSM_ROOT\s*=\s*(.+?)\s*$/m);
  return m ? m[1] : null;
}
const tsm = tsmRoot();
const STAGE = [option("--stage"), process.env.H9WEB_STAGE, path.join(ROOT, "webclient-build", "stage"), tsm && path.join(tsm, "webclient-build", "stage")]
  .filter(Boolean)
  .map((p) => path.resolve(p))
  .find((p) => fs.existsSync(path.join(p, "manifest.json")));

// webclient\: the page files (never DEPLOY.txt, backups or archives) and the package's two lists
const WC = path.join(LOCAL, "webclient");
fs.rmSync(WC, { recursive: true, force: true });
fs.mkdirSync(WC);
const pageDir = path.join(SITE, "webclient");
for (const name of fs.readdirSync(pageDir)) {
  const from = path.join(pageDir, name);
  if (!fs.statSync(from).isFile() || /\.bak/i.test(name) || /\.zip$/i.test(name) || name === "DEPLOY.txt") continue;
  fs.copyFileSync(from, path.join(WC, name));
}
if (STAGE) {
  const LISTS = ["manifest.json", "preload.json"];
  const copyLists = () => {
    for (const name of LISTS) {
      try { fs.copyFileSync(path.join(STAGE, name), path.join(WC, name)); } catch (e) { /* the stage is being rewritten: its next change copies it */ }
    }
  };
  copyLists();
  // export.bat rewrites the stage while the site runs: the lists are copied again a few seconds
  // after either changes, so the page never serves a manifest older than the game files
  let again = null;
  for (const name of LISTS) {
    fs.watchFile(path.join(STAGE, name), { interval: 2000 }, () => { clearTimeout(again); again = setTimeout(copyLists, 3000); });
  }
}

// the downloads' file index: the packages folder, or an empty folder of this PC's copy
const isFolder = (p) => { try { return fs.statSync(p).isDirectory(); } catch (e) { return false; } };
const FILES = [option("--files"), process.env.H9WEB_FILES, path.join(ROOT, "dist")]
  .filter(Boolean)
  .map((p) => path.resolve(p))
  .find(isFolder);
const NO_FILES = path.join(LOCAL, "downloads-files");
if (!FILES) fs.mkdirSync(NO_FILES, { recursive: true });

const SERVERS = path.join(LOCAL, "servers.json");
if (!fs.existsSync(SERVERS)) fs.writeFileSync(SERVERS, JSON.stringify({ servers: [] }, null, 2) + "\n");
// Cloudyman: opt-in local dedicated server for the browser relay.
// The browser addresses this virtual IPv4 server; the relay sends to loopback UDP.
const h9Port = Number(process.env.H9WEB_LOCAL_GAME_PORT || 0);
const h9Advertised = "198.51.100.20";
if (h9Port && Number.isInteger(h9Port) && h9Port >= 1 && h9Port <= 65535) {
  fs.writeFileSync(SERVERS, JSON.stringify({ servers: [
    { name: "HAVOC-NINE (Cloudyman)", address: h9Advertised + ":" + h9Port, target: "127.0.0.1:" + h9Port }
  ] }, null, 2) + "\n");
  const settingsFile = path.join(WC, "settings.json");
  const settings = JSON.parse(fs.readFileSync(settingsFile, "utf8"));
  settings.servers = [{ name: "HAVOC-NINE (Cloudyman)", address: h9Advertised + ":" + h9Port }];
  fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2) + "\n");
}

const MODULES = path.join(HOME, "modules");
const modules = process.env.H9WEB_MODULES
  ? process.env.H9WEB_MODULES.split(",").map((s) => s.trim()).filter(Boolean)
  : fs.existsSync(MODULES)
    ? fs.readdirSync(MODULES).filter((d) => fs.existsSync(path.join(MODULES, d, "index.js"))).sort()
    : [];

const origin = "http://127.0.0.1:" + port;
const publicOrigin = (process.env.H9WEB_PUBLIC_ORIGIN || "").replace(/\/$/, "");
if (publicOrigin && !/^https:\/\/[a-z0-9.-]+(?::443)?$/i.test(publicOrigin)) fail("H9WEB_PUBLIC_ORIGIN must be an HTTPS hostname");
const config = {
  listen: { host: "127.0.0.1", port },
  allowedOrigins: publicOrigin ? [origin, publicOrigin] : [origin],
  dataDir: path.join(LOCAL, "data"),
  serversFile: SERVERS,
  modulesDir: MODULES,
  modules,
  devStatic: {
    "/": SITE,
    "/webclient/": WC,
    ...(STAGE ? { "/webclient/engine/": path.join(STAGE, "engine"), "/webclient/game/": path.join(STAGE, "game") } : {}),
    "/downloads/files/": { dir: FILES || NO_FILES, listing: true },
  },
};
const CONFIG = path.join(LOCAL, "config.json");
fs.writeFileSync(CONFIG, JSON.stringify(config, null, 2) + "\n");

console.log("local-site: " + origin + "/   (Ctrl+C stops it)");
console.log("  site      " + SITE);
console.log("  package   " + (STAGE || "none: PLAY says the client is in preparation"));
console.log("  downloads " + (FILES || "none: /downloads/files/ is an empty index (--files <folder> names one)"));
console.log("  modules   " + (modules.join(", ") || "none"));
console.log("  this PC's accounts and settings: " + LOCAL);

const server = spawn(process.execPath, [path.join(HOME, "server.js"), "--config", CONFIG], { stdio: "inherit", cwd: LOCAL });
server.on("exit", (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
for (const sig of ["SIGINT", "SIGTERM"]) process.on(sig, () => server.kill(sig));

if (args.includes("--open")) {
  setTimeout(() => {
    const url = origin + "/";
    if (process.platform === "win32") spawn("cmd", ["/c", "start", "", url], { stdio: "ignore", detached: true }).unref();
    else spawn(process.platform === "darwin" ? "open" : "xdg-open", [url], { stdio: "ignore", detached: true }).unref();
  }, 1000);
}
