# Drift sync server

Self-hosted **PocketBase** instance — a single Go binary that provides:
- Email/password auth
- Per-user `progress` collection (auto-migrated from `pb_migrations/`)
- Admin UI at `/_/`
- REST API used by the Flutter client

PocketBase stores data in SQLite, so there's no separate database to run.

## Embedded server (recommended for personal use)

The Drift desktop app can run PocketBase itself — no separate VPS, no
`pocketbase serve` terminal. Settings → **SYNC SERVER ON THIS DEVICE** →
toggle on, set a sync password, and the Settings panel shows the LAN URL +
email other devices should use.

To enable this, drop the **`pocketbase.exe`** binary (Linux/macOS: `pocketbase`)
in *one* of these locations:

1. Next to the Drift executable (same folder as `audio_listen.exe`)
2. The Drift app-support directory — Settings will tell you the exact path
   if the binary isn't found
3. Anywhere in your system `PATH`

The first time you enable the toggle, Drift will:
- Run `pocketbase superuser upsert <generated-admin> <generated-password>`
  to provision a hidden admin account
- Spawn `pocketbase serve --http=0.0.0.0:<port>` so LAN devices reach it
- Wait for `/api/health` to respond
- Create a `drift@local` user with the password you chose

Other devices then use the displayed `http://<your-ip>:8090`, email
`drift@local`, and your sync password to sign in.

**Note**: Windows Firewall will prompt for permission the first time
PocketBase listens on `0.0.0.0` — approve to let LAN devices connect.

## Local development

1. **Download** the PocketBase binary for your platform:
   https://pocketbase.io/docs/

2. **Run** it from this directory (it picks up the migrations automatically):

   ```bash
   cd server
   ./pocketbase serve
   ```

   On Windows: `pocketbase.exe serve`

3. **Create the admin account** the first time it prompts you, then open
   the admin UI at http://127.0.0.1:8090/_/

4. **Point the app at it**: in the Flutter app's sign-in screen, use the
   server URL `http://127.0.0.1:8090` (or your LAN IP if running on a
   different machine — e.g. `http://192.168.1.10:8090`).

5. **Create a user**: easiest path is to use the admin UI's "Users"
   collection → New record. The Flutter app also has a "Create account"
   toggle on the sign-in screen.

## Deploying to a VPS

PocketBase is a single binary. Minimal deploy:

```bash
# On the server (assumes Linux/amd64):
curl -L -o pb.zip https://github.com/pocketbase/pocketbase/releases/latest/download/pocketbase_linux_amd64.zip
unzip pb.zip
mkdir -p ~/audio-listen-server/pb_migrations

# Copy this folder's pb_migrations/*.js up there, then:
./pocketbase serve --http=0.0.0.0:8090
```

Put it behind nginx/Caddy with HTTPS — example Caddyfile:

```
sync.example.com {
  reverse_proxy localhost:8090
}
```

For a long-running service, run under systemd:

```ini
# /etc/systemd/system/audio-listen.service
[Unit]
Description=Audio Listen sync (PocketBase)
After=network.target

[Service]
Type=simple
User=audio
WorkingDirectory=/home/audio/audio-listen-server
ExecStart=/home/audio/audio-listen-server/pocketbase serve --http=127.0.0.1:8090
Restart=always

[Install]
WantedBy=multi-user.target
```

## Schema

### `progress` collection

| field               | type     | notes                                       |
|---------------------|----------|---------------------------------------------|
| `user`              | relation | → `users`, cascade delete                   |
| `track_id`          | text     | content-derived ID from the client          |
| `position_ms`       | number   | playback position in milliseconds           |
| `completed`         | bool     | true when track played to end               |
| `client_updated_at` | date     | client-side timestamp (used for LWW merge)  |

Plus PocketBase's built-in `id`, `created`, `updated` fields.

A unique index on `(user, track_id)` makes per-track upserts safe and prevents
duplicates if the client ever races itself.

### `tracks` collection

Stores the actual audio files so Drift can sync your library across devices —
import an audiobook on Windows, see it appear on iOS, tap to download and play.

| field               | type     | notes                                       |
|---------------------|----------|---------------------------------------------|
| `user`              | relation | → `users`, cascade delete                   |
| `track_id`          | text     | content-derived ID (same one as `progress`) |
| `title`             | text     | display title                               |
| `artist`            | text     | optional                                    |
| `album`             | text     | optional                                    |
| `duration_ms`       | number   | optional                                    |
| `file_size`         | number   | informational                               |
| `file_ext`          | text     | `mp3`, `m4b`, etc.                          |
| `file`              | file     | the actual audio file (max 500MB)           |
| `artwork`           | file     | optional, max 10MB                          |
| `client_updated_at` | date     | LWW merge timestamp                         |

Unique index on `(user, track_id)`.

#### Raise the body-size limit

PocketBase's global `maxBodySize` defaults to about 32MB, which is too small
for most audiobooks. After applying this migration:

1. Open the admin UI at `http://<server>:8090/_/`
2. **Settings → Application** → **Max body size**
3. Raise to **600MB** (or higher) to comfortably fit audiobook M4B files

Without this, uploads of large files will fail with HTTP 413.

## Backup

The entire database is `pb_data/data.db`. Stop the server, copy the file,
restart. Or use SQLite's online backup:

```bash
sqlite3 pb_data/data.db ".backup '/path/to/backup.db'"
```
