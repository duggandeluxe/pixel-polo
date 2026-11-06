# Online relay

Online multiplayer needs one small server that both phones connect to. It hands out 4-letter room codes, pairs QUICK MATCH players, and forwards match traffic between the host and the guest. It never runs the game itself.

`worker.js` is that server as a Cloudflare Worker. It's tested locally with `wrangler dev` against two copies of the game.

## Deploy (about 5 minutes)

1. Make a free Cloudflare account at https://dash.cloudflare.com/sign-up.
2. In this folder, run:

   ```bash
   npx wrangler login
   ```

   ```bash
   npx wrangler deploy
   ```

3. Wrangler prints the URL, for example `https://retropolo-relay.<you>.workers.dev`.
4. Put that URL in `game/src/net/net_config.gd`, with `wss://` instead of `https://`:

   ```gdscript
   const RELAY_URL := "wss://retropolo-relay.<you>.workers.dev"
   ```

5. Export the game again. MULTIPLAYER > ONLINE now works on every phone.

## What it costs

The free Workers plan includes Durable Objects. Each match sends about 12 small messages a second while someone attacks, so the free daily limits cover roughly a few hundred matches a day. The $5/month Workers Paid plan covers many thousands. The dashboard's Durable Objects page shows usage.

## Testing without Cloudflare

The same relay also exists in Godot (`game/src/net/relay_server.gd`), and that's what the automated test uses:

```bash
tools/test_mp.sh online
```

To self-host it on any server instead of Cloudflare:

```bash
godot --headless --path game -- --relay 24790
```

Then point `RELAY_URL` at `wss://your-server:24790`. You'll need TLS in front of it, because iOS only allows `wss://`.

To try the Worker itself locally:

```bash
npx wrangler dev --port 8787
```

```bash
godot --headless --path game -- --test mp host online 0.5 3 --relay-url ws://127.0.0.1:8787/
```

```bash
godot --headless --path game -- --test mp join online 0.5 3 --relay-url ws://127.0.0.1:8787/
```
