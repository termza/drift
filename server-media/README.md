# Drift Media Server

A small Docker container that streams audio files from your PC to the
Drift mobile app over your LAN.

- **No uploads** — files stay on disk, streamed on demand
- **Range-request streaming** so scrubbing works on iOS AVPlayer
- **Live-watching** — drop a file into your media folder and it appears in
  the library within ~2 seconds
- **One password** — set `SYNC_PASSWORD`, the iPhone uses that to sign in

## Quick start

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. From this `server-media/` folder:
   ```
   cp .env.example .env
   # edit .env: set a strong SYNC_PASSWORD and (optionally) point
   # MEDIA_DIR_HOST at the folder of audio files you want to expose
   docker compose up -d --build
   ```
3. Confirm it's healthy:
   ```
   curl http://localhost:8090/api/health
   # {"ok":true,"tracks":17}
   ```
4. In Drift on your iPhone:
   - **Server URL**: `http://<your-PC-LAN-IP>:8090`
   - **Email**: `drift@local`
   - **Password**: whatever you set as `SYNC_PASSWORD`

That's it. Drop new files into the media folder anytime — the server's
chokidar watcher picks them up and adds them to the catalog automatically.

## What's in the API

| Endpoint                  | Auth   | Notes                                     |
| ------------------------- | ------ | ----------------------------------------- |
| `GET  /api/health`        | none   | `{ok, tracks}` — handy for liveness probes |
| `POST /api/auth`          | none   | body `{password}` → `{token, sync_email}` |
| `GET  /api/library`       | Bearer | full list of tracks with metadata          |
| `GET  /api/stream/<id>`   | Bearer | streams audio with `Accept-Ranges: bytes`  |
| `GET  /api/artwork/<id>`  | Bearer | embedded cover JPEG/PNG/WebP if present    |

Authentication: send `Authorization: Bearer <SYNC_PASSWORD>` on every
request after `/api/auth`. The token *is* the password — there's no
session management or refresh dance. Simple by design.

## Supported audio formats

`.mp3 .m4a .m4b .aac .wav .flac .ogg .opus .wma .aiff .aif .alac .mka .m4r`

Anything else in the media dir is ignored.

## Finding your LAN IP for iPhone

- Windows: `ipconfig` → look for `IPv4 Address` under your active adapter
  (usually `192.168.x.y`)
- Mac/Linux: `ifconfig | grep "inet "` or `ip addr`

## Security notes

- The shared-password auth is **good enough for a personal LAN**, not for
  exposing the server to the open internet. If you want remote access,
  put it behind Tailscale, WireGuard, or a Caddy reverse proxy with HTTPS.
- The volume is mounted read-only inside the container — even a bug in
  the server can't modify your audio files.
- Files are streamed by ID (a stable SHA-1 of the relative path), so the
  underlying disk paths never leak to the client.

## Troubleshooting

**iPhone can't reach the server:**
- Windows Firewall prompts the first time something binds to `0.0.0.0` —
  approve it.
- Confirm from a browser on the same Wi-Fi: `http://<pc-ip>:8090/api/health`.

**Library is empty:**
- Make sure `MEDIA_DIR_HOST` in `.env` points at a folder that actually
  contains audio files. Check the container logs:
  `docker compose logs -f drift-media` — you should see
  `Indexed N tracks from /media in Xms` at startup.

**Files don't show up after dropping them in:**
- Chokidar's "stable write" debounce is 1.5s — large copies may take a
  beat. If they still don't appear, restart the container to force a
  full scan: `docker compose restart drift-media`.
