// Drift Media Server
// ------------------
// Stream audio files from your PC to the Drift mobile app over your LAN.
// No uploads — files stay on disk and are streamed on demand with HTTP
// range support so seeking + scrubbing work properly.
//
// Auth model is intentionally simple: one shared password, set via the
// SYNC_PASSWORD env var. The client sends it as a Bearer token.
//
// Startup is two-phase:
//   1. Quick filesystem walk — only stat() calls, no audio metadata.
//      Library is immediately populated with filename-derived titles
//      and the HTTP server starts accepting traffic.
//   2. Background metadata enhancer — runs after listen(), opens each
//      file with music-metadata, fills in proper title/artist/album/
//      duration. UI updates as records get enhanced.
//
// This avoids the "container stays unhealthy for 10 minutes scanning
// my 9GB Downloads folder" problem.

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

// In-memory library keyed by stable id (sha1 of relative path).
// Each entry: {id, path, title, artist, album, duration_ms, file_size,
//              file_ext, has_artwork, mtime, enhanced}
const library = new Map();

let scanState = { phase: 'idle', scanned: 0, enhanced: 0 };

function stableId(relPath) {
  return crypto.createHash('sha1').update(relPath).digest('hex').slice(0, 16);
}

// Fast registration — just stat the file. No tags read.
async function registerFile(fullPath, stat = null) {
  try {
    stat = stat || (await fs.promises.stat(fullPath));
    const rel = path.relative(MEDIA_DIR, fullPath);
    const id = stableId(rel);
    const ext = path.extname(fullPath).slice(1).toLowerCase();
    const fallbackTitle = path
      .basename(fullPath, path.extname(fullPath))
      .replace(/_/g, ' ')
      .trim();
    library.set(id, {
      id,
      path: fullPath,
      title: fallbackTitle,
      artist: null,
      album: null,
      duration_ms: null,
      file_size: stat.size,
      file_ext: ext,
      has_artwork: false,
      mtime: stat.mtime.toISOString(),
      enhanced: false,
    });
    return id;
  } catch (e) {
    console.error(`register failed for ${fullPath}: ${e.message}`);
    return null;
  }
}

// Slow enhancement — reads tags. Called in background after listen().
async function enhanceFile(id) {
  const t = library.get(id);
  if (!t || t.enhanced) return;
  try {
    const meta = await mm.parseFile(t.path, { duration: true });
    const c = meta.common || {};
    const f = meta.format || {};
    t.title = (c.title || t.title).trim();
    t.artist = (c.artist || '').trim() || null;
    t.album = (c.album || '').trim() || null;
    t.duration_ms = f.duration ? Math.round(f.duration * 1000) : null;
    t.has_artwork = !!(c.picture && c.picture.length);
    t.enhanced = true;
  } catch (e) {
    // Broken tags don't stop the file from playing — just leave the
    // filename-derived title and move on.
    t.enhanced = true;
  }
}

async function fastScan() {
  library.clear();
  scanState = { phase: 'walking', scanned: 0, enhanced: 0 };
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
        await registerFile(full);
        scanState.scanned = library.size;
      }
    }
  };
  await walk(MEDIA_DIR);
  console.log(
    `[scan] indexed ${library.size} files from ${MEDIA_DIR} in ${Date.now() - start}ms`
  );
  scanState.phase = 'enhancing';
}

// Process metadata enhancements N at a time in the background.
async function enhanceAll(concurrency = 4) {
  const ids = [...library.keys()];
  let i = 0;
  let done = 0;
  const next = async () => {
    while (i < ids.length) {
      const id = ids[i++];
      await enhanceFile(id);
      done++;
      scanState.enhanced = done;
      if (done % 25 === 0) {
        console.log(`[enhance] ${done}/${ids.length}`);
      }
    }
  };
  await Promise.all(Array.from({ length: concurrency }, next));
  console.log(`[enhance] done — ${done} tracks fully enriched`);
  scanState.phase = 'idle';
}

function startWatcher() {
  const watcher = chokidar.watch(MEDIA_DIR, {
    ignoreInitial: true,
    awaitWriteFinish: { stabilityThreshold: 1500, pollInterval: 300 },
    // Skip a few well-known noisy directories so chokidar doesn't melt
    // when MEDIA_DIR is a general Downloads folder.
    ignored: /(^|[\\/])\.(?:git|svn|hg|cache|tmp|Trash)/,
  });
  watcher.on('add', async (p) => {
    if (!AUDIO_EXT.has(path.extname(p).toLowerCase())) return;
    const id = await registerFile(p);
    if (id) {
      enhanceFile(id).catch(() => {});
      console.log(`+ ${path.relative(MEDIA_DIR, p)}`);
    }
  });
  watcher.on('change', async (p) => {
    if (!AUDIO_EXT.has(path.extname(p).toLowerCase())) return;
    const id = await registerFile(p);
    if (id) {
      const t = library.get(id);
      if (t) t.enhanced = false;
      enhanceFile(id).catch(() => {});
      console.log(`~ ${path.relative(MEDIA_DIR, p)}`);
    }
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
  res.json({
    ok: true,
    tracks: library.size,
    phase: scanState.phase,
    scanned: scanState.scanned,
    enhanced: scanState.enhanced,
  });
});

app.post('/api/auth', (req, res) => {
  const pw = (req.body && req.body.password) || '';
  if (pw === PASSWORD) {
    res.json({ token: PASSWORD, sync_email: 'drift@local' });
  } else {
    res.status(401).json({ error: 'wrong password' });
  }
});

app.get('/api/library', requireAuth, (_req, res) => {
  const tracks = [];
  for (const t of library.values()) {
    const { path: _omit, enhanced: _omit2, ...safe } = t;
    tracks.push(safe);
  }
  tracks.sort((a, b) => (a.mtime < b.mtime ? 1 : -1));
  res.json({ tracks });
});

app.get('/api/stream/:id', requireAuth, (req, res) => {
  const t = library.get(req.params.id);
  if (!t) return res.status(404).end();

  let stat;
  try {
    stat = fs.statSync(t.path);
  } catch (_) {
    library.delete(req.params.id);
    return res.status(404).end();
  }
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

  const m = /^bytes=(\d*)-(\d*)$/.exec(range);
  if (!m) {
    return res.status(416).set('Content-Range', `bytes */${size}`).end();
  }
  let start = m[1] === '' ? size - parseInt(m[2], 10) : parseInt(m[1], 10);
  let end = m[2] === '' ? size - 1 : parseInt(m[2], 10);
  if (Number.isNaN(start) || Number.isNaN(end) || start > end || end >= size) {
    return res.status(416).set('Content-Range', `bytes */${size}`).end();
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
  if (!t) return res.status(404).end();
  // If we haven't enhanced this track yet, do it now so the picture is
  // available — first artwork request triggers a lazy parse.
  if (!t.enhanced) await enhanceFile(t.id);
  if (!t.has_artwork) return res.status(404).end();
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
  // Step 1 — fast walk, just enough to know what's there.
  await fastScan();
  // Step 2 — start serving immediately. /api/library returns whatever
  // we've indexed so far; clients see filename-derived titles right away.
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[server] listening on 0.0.0.0:${PORT}`);
  });
  // Step 3 — fill in proper metadata in the background.
  startWatcher();
  enhanceAll().catch((e) => console.error('[enhance] crashed:', e));
})();
