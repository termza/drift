// Drift Media Server
// ------------------
// Stream audio files from your PC to the Drift mobile app over your LAN.
// No uploads — files stay on disk and are streamed on demand with HTTP
// range support so seeking + scrubbing work properly.
//
// Auth model is intentionally simple: one shared password, set via the
// SYNC_PASSWORD env var. The client sends it as a Bearer token. Good
// enough for a personal home-network setup; pair with Tailscale or a
// reverse proxy if you want to expose it beyond LAN.

const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const mm = require('music-metadata');
const chokidar = require('chokidar');

const MEDIA_DIR = process.env.MEDIA_DIR || '/media';
const PASSWORD = process.env.SYNC_PASSWORD;
const PORT = parseInt(process.env.PORT || '8090', 10);

if (!PASSWORD) {
  console.error('FATAL: SYNC_PASSWORD env var is required.');
  process.exit(1);
}

const AUDIO_EXT = new Set([
  '.mp3', '.m4a', '.m4b', '.aac', '.wav', '.flac', '.ogg', '.opus',
  '.wma', '.aiff', '.aif', '.alac', '.mka', '.m4r',
]);

const MIME_BY_EXT = {
  mp3: 'audio/mpeg',
  m4a: 'audio/mp4',
  m4b: 'audio/mp4',
  aac: 'audio/aac',
  wav: 'audio/wav',
  flac: 'audio/flac',
  ogg: 'audio/ogg',
  opus: 'audio/opus',
  wma: 'audio/x-ms-wma',
  aiff: 'audio/aiff',
  aif: 'audio/aiff',
  alac: 'audio/mp4',
  mka: 'audio/x-matroska',
  m4r: 'audio/mp4',
};

// In-memory library: { id -> {id, path, title, artist, album, duration_ms,
//                            file_size, file_ext, has_artwork, mtime} }
const library = new Map();

function stableId(relPath) {
  return crypto.createHash('sha1').update(relPath).digest('hex').slice(0, 16);
}

async function indexFile(fullPath) {
  try {
    const stat = await fs.promises.stat(fullPath);
    const rel = path.relative(MEDIA_DIR, fullPath);
    const id = stableId(rel);
    const ext = path.extname(fullPath).slice(1).toLowerCase();

    let meta = {};
    try {
      meta = await mm.parseFile(fullPath, { duration: true });
    } catch (e) {
      // Files with broken tags still play — just fall back to filename.
    }

    const c = meta.common || {};
    const f = meta.format || {};
    const fallbackTitle = path.basename(fullPath, path.extname(fullPath));

    library.set(id, {
      id,
      path: fullPath,
      title: (c.title || fallbackTitle).trim(),
      artist: (c.artist || '').trim() || null,
      album: (c.album || '').trim() || null,
      duration_ms: f.duration ? Math.round(f.duration * 1000) : null,
      file_size: stat.size,
      file_ext: ext,
      has_artwork: !!(c.picture && c.picture.length),
      mtime: stat.mtime.toISOString(),
    });
  } catch (e) {
    console.error(`index failed for ${fullPath}: ${e.message}`);
  }
}

async function fullScan() {
  library.clear();
  const start = Date.now();
  const walk = async (dir) => {
    let entries;
    try {
      entries = await fs.promises.readdir(dir, { withFileTypes: true });
    } catch (e) {
      console.error(`readdir failed for ${dir}: ${e.message}`);
      return;
    }
    for (const e of entries) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) {
        await walk(full);
      } else if (e.isFile() && AUDIO_EXT.has(path.extname(e.name).toLowerCase())) {
        await indexFile(full);
      }
    }
  };
  await walk(MEDIA_DIR);
  console.log(
    `Indexed ${library.size} tracks from ${MEDIA_DIR} in ${Date.now() - start}ms`
  );
}

function startWatcher() {
  const watcher = chokidar.watch(MEDIA_DIR, {
    ignoreInitial: true,
    awaitWriteFinish: { stabilityThreshold: 1500, pollInterval: 300 },
  });
  watcher.on('add', async (p) => {
    if (!AUDIO_EXT.has(path.extname(p).toLowerCase())) return;
    await indexFile(p);
    console.log(`+ ${path.relative(MEDIA_DIR, p)}`);
  });
  watcher.on('change', async (p) => {
    if (!AUDIO_EXT.has(path.extname(p).toLowerCase())) return;
    await indexFile(p);
    console.log(`~ ${path.relative(MEDIA_DIR, p)}`);
  });
  watcher.on('unlink', (p) => {
    const rel = path.relative(MEDIA_DIR, p);
    const id = stableId(rel);
    if (library.delete(id)) console.log(`- ${rel}`);
  });
}

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------

const app = express();
app.use(express.json({ limit: '64kb' }));

function requireAuth(req, res, next) {
  const h = req.headers.authorization || '';
  const m = h.match(/^Bearer\s+(.+)$/);
  if (m && m[1] === PASSWORD) return next();
  res.status(401).json({ error: 'unauthorized' });
}

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, tracks: library.size });
});

app.post('/api/auth', (req, res) => {
  const pw = (req.body && req.body.password) || '';
  if (pw === PASSWORD) {
    // Token is just the password itself — simple and replaceable. The client
    // already had to know the password to call this endpoint.
    res.json({ token: PASSWORD, sync_email: 'drift@local' });
  } else {
    res.status(401).json({ error: 'wrong password' });
  }
});

app.get('/api/library', requireAuth, (_req, res) => {
  const tracks = [];
  for (const t of library.values()) {
    // Don't leak the absolute disk path.
    const { path: _omit, ...safe } = t;
    tracks.push(safe);
  }
  // Newest first by mtime so freshly-dropped files surface in the app.
  tracks.sort((a, b) => (a.mtime < b.mtime ? 1 : -1));
  res.json({ tracks });
});

app.get('/api/stream/:id', requireAuth, (req, res) => {
  const t = library.get(req.params.id);
  if (!t) return res.status(404).end();

  const stat = fs.statSync(t.path);
  const size = stat.size;
  const range = req.headers.range;

  const mime = MIME_BY_EXT[t.file_ext] || 'application/octet-stream';
  if (!range) {
    res.writeHead(200, {
      'Content-Type': mime,
      'Content-Length': size,
      'Accept-Ranges': 'bytes',
    });
    fs.createReadStream(t.path).pipe(res);
    return;
  }

  // Parse "bytes=START-END" range.
  const m = /^bytes=(\d*)-(\d*)$/.exec(range);
  if (!m) {
    res.status(416).set('Content-Range', `bytes */${size}`).end();
    return;
  }
  let start = m[1] === '' ? size - parseInt(m[2], 10) : parseInt(m[1], 10);
  let end = m[2] === '' ? size - 1 : parseInt(m[2], 10);
  if (Number.isNaN(start) || Number.isNaN(end) || start > end || end >= size) {
    res.status(416).set('Content-Range', `bytes */${size}`).end();
    return;
  }
  res.writeHead(206, {
    'Content-Type': mime,
    'Content-Length': end - start + 1,
    'Content-Range': `bytes ${start}-${end}/${size}`,
    'Accept-Ranges': 'bytes',
  });
  fs.createReadStream(t.path, { start, end }).pipe(res);
});

app.get('/api/artwork/:id', requireAuth, async (req, res) => {
  const t = library.get(req.params.id);
  if (!t || !t.has_artwork) return res.status(404).end();
  try {
    const meta = await mm.parseFile(t.path, { duration: false, skipCovers: false });
    const pic = meta.common.picture && meta.common.picture[0];
    if (!pic) return res.status(404).end();
    res.set('Content-Type', pic.format).set('Cache-Control', 'public, max-age=86400');
    res.send(pic.data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

(async () => {
  console.log(`drift-media starting…  MEDIA_DIR=${MEDIA_DIR}  PORT=${PORT}`);
  if (!fs.existsSync(MEDIA_DIR)) {
    console.error(`MEDIA_DIR does not exist: ${MEDIA_DIR}`);
    process.exit(1);
  }
  await fullScan();
  startWatcher();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Listening on 0.0.0.0:${PORT}`);
  });
})();
