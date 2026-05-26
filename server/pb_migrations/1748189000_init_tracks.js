/// <reference path="../pb_data/types.d.ts" />

// Creates the `tracks` collection used to sync the actual audio files between
// devices. Each row owns one user's audio file via the `file` field. The
// `track_id` mirrors the client-side content-derived ID so the local library
// and cloud catalog can dedupe against each other.
//
// IMPORTANT: PocketBase's global `maxBodySize` defaults to ~32MB, which is too
// small for many audiobooks. After applying this migration, raise the limit
// from the PocketBase admin UI (Settings → Application → Max body size) — see
// `server/README.md` for guidance.
migrate((app) => {
  const collection = new Collection({
    name: 'tracks',
    type: 'base',

    listRule:   '@request.auth.id != "" && user = @request.auth.id',
    viewRule:   '@request.auth.id != "" && user = @request.auth.id',
    createRule: '@request.auth.id != "" && user = @request.auth.id',
    updateRule: '@request.auth.id != "" && user = @request.auth.id',
    deleteRule: '@request.auth.id != "" && user = @request.auth.id',

    fields: [
      {
        name: 'user',
        type: 'relation',
        required: true,
        collectionId: '_pb_users_auth_',
        cascadeDelete: true,
        maxSelect: 1,
      },
      { name: 'track_id',    type: 'text',   required: true, max: 128 },
      { name: 'title',       type: 'text',   max: 500 },
      { name: 'artist',      type: 'text',   max: 500 },
      { name: 'album',       type: 'text',   max: 500 },
      { name: 'duration_ms', type: 'number', min: 0 },
      { name: 'file_size',   type: 'number', min: 0 },
      { name: 'file_ext',    type: 'text',   max: 16 },
      {
        name: 'file',
        type: 'file',
        required: true,
        maxSelect: 1,
        // 500MB per file — most audiobooks fit comfortably under this.
        maxSize: 524288000,
      },
      {
        name: 'artwork',
        type: 'file',
        maxSelect: 1,
        maxSize: 10485760, // 10MB
        mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
      },
      { name: 'client_updated_at', type: 'date', required: true },
    ],

    indexes: [
      'CREATE UNIQUE INDEX idx_tracks_user_track ON tracks (user, track_id)',
      'CREATE INDEX idx_tracks_user_updated ON tracks (user, updated)',
    ],
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId('tracks');
  return app.delete(collection);
});
