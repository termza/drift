# Audio Listen

A clean, modern audio player for iOS and Windows. Plays your own mp3/m4a/etc.
files, with progress saved per-track and (optionally) synced across devices.

## Architecture

- **Flutter** — single codebase for iOS + Windows (also runs on macOS/Android/Linux).
- **just_audio** + **just_audio_media_kit** — playback on all platforms.
- **just_audio_background** — iOS lock-screen / Control Center integration.
- **sqflite** (mobile) + **sqflite_common_ffi** (desktop) — local progress store.
- **Riverpod** — state management.
- **Local-first**: progress is written to SQLite immediately; `SyncService`
  reconciles in the background when a backend is plugged in.

```
lib/
├── main.dart              # platform init + DB open
├── app.dart               # MaterialApp + theme
├── theme/                 # colors + typography
├── models/                # Track, TrackProgress
├── services/              # audio player, library, progress, sync
├── state/                 # Riverpod providers
├── widgets/               # mini player, track tile, artwork
└── screens/               # root shell, library, player, settings
```

## First-time setup

Flutter isn't installed yet. To get going:

### 1. Install Flutter

- Windows: https://docs.flutter.dev/get-started/install/windows
- After install, run `flutter doctor` and resolve any warnings.

### 2. Generate platform folders

This repo only ships the Dart source. Generate the `ios/`, `windows/`,
etc. native shells once:

```bash
cd "D:/zcuf/audio listen"
flutter create --platforms=ios,windows,macos,android .
flutter pub get
```

### 3. Platform-specific config

**iOS** — edit `ios/Runner/Info.plist`, add:

```xml
<key>UIBackgroundModes</key>
<array><string>audio</string></array>
```

**Windows** — `just_audio_media_kit` uses `libmpv`. Add to
`windows/runner/CMakeLists.txt` (it pulls in `media_kit_libs_audio` automatically
via `media_kit_libs_audio_windows`).

### 4. Run

```bash
flutter run -d windows
flutter run -d <ios-device-id>
```

## Sync server

Cross-device sync uses a self-hosted **PocketBase** instance — a single Go
binary that bundles auth, REST API, SQLite storage, and an admin UI. Setup
lives in [`server/`](server/README.md); short version:

1. Download the PocketBase binary into `server/`
2. `./pocketbase serve` — picks up `pb_migrations/` automatically
3. In the app's Settings → Sign in, enter your server URL + credentials

The app is **offline-first**: progress writes hit local SQLite immediately,
and `SyncService` reconciles with the server in the background (on app start,
on resume, every minute while playing, and after sign-in). Conflicts are
resolved last-write-wins on `client_updated_at`.

If you ever want a different backend (Supabase, custom HTTP, etc.),
implement `SyncBackend` in `lib/services/` and swap it in
`syncServiceProvider` — the rest of the app doesn't change.

## Design notes

- Dark-first; light theme is a refined inversion.
- Accent: warm copper (`#E5A06B`) — distinctive without being trendy.
- Typography: Inter (UI) with tightened letter-spacing on headings.
- Artwork falls back to a hue-seeded gradient + monogram when ID3 has none.
- The mini player slides up into the full Now Playing screen via a hero on the
  artwork.
