/// <reference path="../pb_data/types.d.ts" />

// Creates the `progress` collection used to sync per-track playback position
// across the user's devices. Each row is owned by exactly one user via the
// `user` relation; PocketBase rules guarantee that users can only ever see or
// modify their own rows.
migrate((app) => {
  const collection = new Collection({
    name: 'progress',
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
      { name: 'position_ms', type: 'number', required: true, min: 0 },
      { name: 'completed',   type: 'bool' },
      { name: 'client_updated_at', type: 'date', required: true },
    ],

    indexes: [
      'CREATE UNIQUE INDEX idx_progress_user_track ON progress (user, track_id)',
      'CREATE INDEX idx_progress_user_updated ON progress (user, updated)',
    ],
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId('progress');
  return app.delete(collection);
});
