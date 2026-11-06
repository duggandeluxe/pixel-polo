// Retro Polo online relay: a Cloudflare Worker with Durable Objects.
//
// Same protocol as game/src/net/relay_server.gd (see game/src/net/relay_transport.gd):
// a phone opens a WebSocket with its hello in the query string (?op=host|join|quick&g&v&name&code),
// then sends the same hello as JSON. Text frames are JSON control messages; binary frames are
// [peer id] + payload. Host -> relay: the target peer. Relay -> host: the sender.
//
// One Durable Object per room (named by its 4-letter code) forwards frames between the host
// and its guest. One Matchmaker object pairs QUICK MATCH players.

const CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const MAX_ROOM = 2;
const REASON_MAX = 120;   // a WebSocket close reason holds at most 123 bytes

function newCode() {
  let s = "";
  for (let i = 0; i < 4; i++) s += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
  return s;
}

function cleanCode(c) {
  return String(c || "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 4);
}

// Says why, then closes. The reason also rides in the close frame: a phone can see the
// socket close before the text message arrives, and the close reason always gets through.
function sendAndClose(ws, msg, why) {
  try {
    ws.send(JSON.stringify(msg));
    ws.close(1000, why.slice(0, REASON_MAX));
  } catch (e) { /* already closed */ }
}

// A socket that only says why it can't go on, then closes.
function refuse(why) {
  const pair = new WebSocketPair();
  const [client, server] = Object.values(pair);
  server.accept();
  sendAndClose(server, { op: "error", why }, why);
  return new Response(null, { status: 101, webSocket: client });
}

export default {
  async fetch(request, env) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Retro Polo relay. Connect with a WebSocket.", { status: 200 });
    }
    const url = new URL(request.url);
    const op = url.searchParams.get("op");
    let code = cleanCode(url.searchParams.get("code"));
    let role = op;
    if (op === "quick") {
      const mm = env.MATCHMAKER.get(env.MATCHMAKER.idFromName("global"));
      const r = await (await mm.fetch("https://mm/quick", {
        method: "POST",
        body: JSON.stringify({ g: url.searchParams.get("g"), v: url.searchParams.get("v") }),
      })).json();
      code = r.code;
      role = r.role;
    } else if (op === "host") {
      code = newCode();
    } else if (op !== "join" || code.length !== 4) {
      return refuse("Bad request");
    }
    const room = env.ROOMS.get(env.ROOMS.idFromName(code));
    const fwd = new URL(request.url);
    fwd.searchParams.set("role", role);
    fwd.searchParams.set("code", code);
    fwd.searchParams.set("quick", op === "quick" ? "1" : "0");
    return room.fetch(new Request(fwd.toString(), request));
  },
};

export class Room {
  constructor(state, env) {
    this.env = env;
    this.code = "";
    this.host = null;
    this.guests = new Map();   // id -> socket
    this.quick = false;
    this.g = "";
    this.v = "";
  }

  async fetch(request) {
    const url = new URL(request.url);
    const role = url.searchParams.get("role");
    const g = url.searchParams.get("g") || "";
    const v = url.searchParams.get("v") || "";
    const name = (url.searchParams.get("name") || "").slice(0, 10);
    this.code = url.searchParams.get("code");
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    if (role === "host") {
      if (this.host) {
        // a code collision: extremely rare, the phone can just try again
        sendAndClose(server, { op: "error", why: "Room busy, try again" }, "Room busy, try again");
        return new Response(null, { status: 101, webSocket: client });
      }
      this.host = server;
      this.quick = url.searchParams.get("quick") === "1";
      this.g = g;
      this.v = v;
      server.send(JSON.stringify({ op: "room", code: this.code }));
      server.addEventListener("message", (ev) => this.fromHost(ev.data));
      server.addEventListener("close", () => this.hostLeft());
      server.addEventListener("error", () => this.hostLeft());
    } else {
      let why = "";
      if (!this.host) why = `No room ${this.code}. Check the code.`;
      else if (this.g !== g || this.v !== v) why = "Different game version: update both phones";
      else if (this.guests.size + 1 >= MAX_ROOM) why = "That room is full";
      if (why) {
        sendAndClose(server, { op: "error", why }, why);
        return new Response(null, { status: 101, webSocket: client });
      }
      let id = 2;
      while (this.guests.has(id)) id++;
      this.guests.set(id, server);
      server.send(JSON.stringify({ op: "joined", id, code: this.code }));
      this.host.send(JSON.stringify({ op: "peer", id, name }));
      server.addEventListener("message", (ev) => this.fromGuest(id, ev.data));
      server.addEventListener("close", () => this.guestLeft(id));
      server.addEventListener("error", () => this.guestLeft(id));
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  fromHost(data) {
    if (typeof data === "string") return;            // the JSON hello: already handled
    const bytes = new Uint8Array(data);
    if (bytes.length < 1) return;
    const to = this.guests.get(bytes[0]);
    if (!to) return;
    const out = new Uint8Array(bytes.length);
    out.set(bytes);
    out[0] = 1;
    try { to.send(out); } catch (e) { /* the guest is gone; its close handler cleans up */ }
  }

  fromGuest(id, data) {
    if (typeof data === "string" || !this.host) return;
    const bytes = new Uint8Array(data);
    if (bytes.length < 1) return;
    const out = new Uint8Array(bytes.length);
    out.set(bytes);
    out[0] = id;
    try { this.host.send(out); } catch (e) { /* the host is gone */ }
  }

  async hostLeft() {
    if (!this.host) return;
    this.host = null;
    for (const [, ws] of this.guests) {
      sendAndClose(ws, { op: "closed", why: "The host left" }, "The host left");
    }
    this.guests.clear();
    if (this.quick) {
      const mm = this.env.MATCHMAKER.get(this.env.MATCHMAKER.idFromName("global"));
      await mm.fetch("https://mm/cancel", { method: "POST", body: JSON.stringify({ code: this.code }) });
    }
  }

  async guestLeft(id) {
    if (!this.guests.delete(id) || !this.host) return;
    try { this.host.send(JSON.stringify({ op: "left", id })); } catch (e) { /* host gone */ }
    if (this.quick && this.guests.size === 0) {
      // their opponent left: put this host back in the quick-match line
      const mm = this.env.MATCHMAKER.get(this.env.MATCHMAKER.idFromName("global"));
      await mm.fetch("https://mm/requeue", {
        method: "POST",
        body: JSON.stringify({ code: this.code, g: this.g, v: this.v }),
      });
    }
  }
}

// Pairs QUICK MATCH players: the first one hosts a room, the next one joins it. Rooms
// leave the line when their host leaves (/cancel) and come back when their opponent
// leaves (/requeue), so nobody waits in a room nobody can find.
export class Matchmaker {
  constructor() {
    this.waiting = new Map();   // "g:v" -> [room codes], oldest first
  }

  line(key) {
    if (!this.waiting.has(key)) this.waiting.set(key, []);
    return this.waiting.get(key);
  }

  async fetch(request) {
    const url = new URL(request.url);
    const body = await request.json();
    if (url.pathname === "/cancel") {
      for (const [k, codes] of this.waiting) this.waiting.set(k, codes.filter((c) => c !== body.code));
      return new Response("ok");
    }
    const key = `${body.g}:${body.v}`;
    const codes = this.line(key);
    if (url.pathname === "/requeue") {
      if (!codes.includes(body.code)) codes.push(body.code);
      return new Response("ok");
    }
    if (codes.length > 0) {
      return Response.json({ code: codes.shift(), role: "join" });
    }
    const code = newCode();
    codes.push(code);
    return Response.json({ code, role: "host" });
  }
}
