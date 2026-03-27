-- Reframe: Initial Schema Migration
-- Version: 001
-- Date: 2026-03-27

-- Enable WAL mode for concurrent read access
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;

-- ============================================================
-- USERS & AUTH
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
    id                TEXT PRIMARY KEY,
    username          TEXT NOT NULL UNIQUE,
    email             TEXT UNIQUE,
    password_hash     TEXT NOT NULL,
    display_name      TEXT NOT NULL,
    role              TEXT NOT NULL DEFAULT 'user',
    storage_quota_bytes INTEGER DEFAULT 0,
    storage_used_bytes  INTEGER DEFAULT 0,
    locked_folder_pin_hash TEXT,
    is_active         INTEGER NOT NULL DEFAULT 1,
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS invite_codes (
    id                TEXT PRIMARY KEY,
    code              TEXT NOT NULL UNIQUE,
    created_by        TEXT NOT NULL REFERENCES users(id),
    used_by           TEXT REFERENCES users(id),
    expires_at        TEXT,
    is_used           INTEGER NOT NULL DEFAULT 0,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL,
    device_name       TEXT,
    device_type       TEXT,
    last_active_at    TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at        TEXT NOT NULL,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

-- ============================================================
-- ASSETS
-- ============================================================

CREATE TABLE IF NOT EXISTS assets (
    id                TEXT PRIMARY KEY,
    owner_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    file_hash         TEXT NOT NULL,
    file_name         TEXT NOT NULL,
    file_size_bytes   INTEGER NOT NULL,
    mime_type         TEXT NOT NULL,
    asset_type        TEXT NOT NULL,
    status            TEXT NOT NULL DEFAULT 'uploading',
    width             INTEGER,
    height            INTEGER,
    duration_seconds  REAL,
    blurhash          TEXT,

    -- Storage paths
    original_path     TEXT NOT NULL,
    thumbnail_tiny    TEXT,
    thumbnail_small   TEXT,
    thumbnail_medium  TEXT,
    video_hls_path    TEXT,

    -- Temporal
    captured_at       TEXT,
    timezone          TEXT,

    -- Location
    latitude          REAL,
    longitude         REAL,
    altitude          REAL,
    location_name     TEXT,
    location_country  TEXT,

    -- EXIF / Metadata
    camera_make       TEXT,
    camera_model      TEXT,
    lens_model        TEXT,
    focal_length      REAL,
    aperture          REAL,
    shutter_speed     TEXT,
    iso               INTEGER,
    flash_fired       INTEGER,
    orientation       INTEGER,
    color_space       TEXT,
    exif_json         TEXT,

    -- Organization
    is_favorite       INTEGER NOT NULL DEFAULT 0,
    is_archived       INTEGER NOT NULL DEFAULT 0,
    is_locked         INTEGER NOT NULL DEFAULT 0,
    is_deleted        INTEGER NOT NULL DEFAULT 0,
    deleted_at        TEXT,

    -- ML Processing Status
    ml_faces_processed    INTEGER NOT NULL DEFAULT 0,
    ml_clip_processed     INTEGER NOT NULL DEFAULT 0,
    ml_ocr_processed      INTEGER NOT NULL DEFAULT 0,

    -- OCR
    ocr_text          TEXT,

    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at        TEXT NOT NULL DEFAULT (datetime('now')),

    UNIQUE(owner_id, file_hash)
);

CREATE INDEX IF NOT EXISTS idx_assets_owner_captured ON assets(owner_id, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_assets_owner_type ON assets(owner_id, asset_type);
CREATE INDEX IF NOT EXISTS idx_assets_owner_favorite ON assets(owner_id, is_favorite) WHERE is_favorite = 1;
CREATE INDEX IF NOT EXISTS idx_assets_owner_archived ON assets(owner_id, is_archived) WHERE is_archived = 1;
CREATE INDEX IF NOT EXISTS idx_assets_owner_deleted ON assets(owner_id, is_deleted) WHERE is_deleted = 1;
CREATE INDEX IF NOT EXISTS idx_assets_owner_locked ON assets(owner_id, is_locked) WHERE is_locked = 1;
CREATE INDEX IF NOT EXISTS idx_assets_location ON assets(latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_assets_hash ON assets(file_hash);
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status) WHERE status != 'ready';

-- ============================================================
-- FACE RECOGNITION
-- ============================================================

CREATE TABLE IF NOT EXISTS people (
    id                TEXT PRIMARY KEY,
    owner_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name              TEXT,
    representative_face_id TEXT,
    merge_target_id   TEXT REFERENCES people(id),
    is_hidden         INTEGER NOT NULL DEFAULT 0,
    photo_count       INTEGER NOT NULL DEFAULT 0,
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_people_owner ON people(owner_id);

CREATE TABLE IF NOT EXISTS faces (
    id                TEXT PRIMARY KEY,
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    person_id         TEXT REFERENCES people(id) ON DELETE SET NULL,
    embedding         BLOB NOT NULL,
    bounding_box      TEXT NOT NULL,
    confidence        REAL NOT NULL,
    thumbnail_path    TEXT,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_faces_asset ON faces(asset_id);
CREATE INDEX IF NOT EXISTS idx_faces_person ON faces(person_id);

-- ============================================================
-- CLIP EMBEDDINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS clip_embeddings (
    asset_id          TEXT PRIMARY KEY REFERENCES assets(id) ON DELETE CASCADE,
    embedding         BLOB NOT NULL,
    model_version     TEXT NOT NULL DEFAULT 'ViT-B/32',
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================================
-- ALBUMS
-- ============================================================

CREATE TABLE IF NOT EXISTS albums (
    id                TEXT PRIMARY KEY,
    owner_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title             TEXT NOT NULL,
    description       TEXT,
    cover_asset_id    TEXT REFERENCES assets(id) ON DELETE SET NULL,
    album_type        TEXT NOT NULL DEFAULT 'manual',
    sort_order        TEXT NOT NULL DEFAULT 'captured_at_desc',
    is_shared         INTEGER NOT NULL DEFAULT 0,
    share_token       TEXT UNIQUE,
    share_permissions TEXT NOT NULL DEFAULT 'view',
    share_requires_auth INTEGER NOT NULL DEFAULT 0,
    asset_count       INTEGER NOT NULL DEFAULT 0,
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_albums_owner ON albums(owner_id);
CREATE INDEX IF NOT EXISTS idx_albums_share_token ON albums(share_token) WHERE share_token IS NOT NULL;

CREATE TABLE IF NOT EXISTS album_assets (
    album_id          TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    sort_index        INTEGER NOT NULL DEFAULT 0,
    added_by          TEXT REFERENCES users(id),
    added_at          TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (album_id, asset_id)
);

CREATE INDEX IF NOT EXISTS idx_album_assets_asset ON album_assets(asset_id);

CREATE TABLE IF NOT EXISTS album_collaborators (
    album_id          TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role              TEXT NOT NULL DEFAULT 'viewer',
    joined_at         TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (album_id, user_id)
);

-- ============================================================
-- SHARING
-- ============================================================

CREATE TABLE IF NOT EXISTS share_links (
    id                TEXT PRIMARY KEY,
    token             TEXT NOT NULL UNIQUE,
    created_by        TEXT NOT NULL REFERENCES users(id),
    share_type        TEXT NOT NULL,
    target_id         TEXT NOT NULL,
    permissions       TEXT NOT NULL DEFAULT 'view',
    requires_auth     INTEGER NOT NULL DEFAULT 0,
    password_hash     TEXT,
    max_views         INTEGER,
    view_count        INTEGER NOT NULL DEFAULT 0,
    expires_at        TEXT,
    is_active         INTEGER NOT NULL DEFAULT 1,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_share_links_token ON share_links(token);
CREATE INDEX IF NOT EXISTS idx_share_links_target ON share_links(share_type, target_id);

CREATE TABLE IF NOT EXISTS share_link_assets (
    share_link_id     TEXT NOT NULL REFERENCES share_links(id) ON DELETE CASCADE,
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    PRIMARY KEY (share_link_id, asset_id)
);

-- ============================================================
-- PARTNER SHARING
-- ============================================================

CREATE TABLE IF NOT EXISTS partner_sharing (
    id                TEXT PRIMARY KEY,
    from_user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    share_mode        TEXT NOT NULL DEFAULT 'all',
    is_active         INTEGER NOT NULL DEFAULT 1,
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(from_user_id, to_user_id)
);

CREATE TABLE IF NOT EXISTS partner_sharing_people (
    partner_sharing_id TEXT NOT NULL REFERENCES partner_sharing(id) ON DELETE CASCADE,
    person_id          TEXT NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    PRIMARY KEY (partner_sharing_id, person_id)
);

-- ============================================================
-- MEMORIES
-- ============================================================

CREATE TABLE IF NOT EXISTS memories (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    memory_type       TEXT NOT NULL,
    title             TEXT NOT NULL,
    description       TEXT,
    date_reference    TEXT,
    is_seen           INTEGER NOT NULL DEFAULT 0,
    is_dismissed      INTEGER NOT NULL DEFAULT 0,
    generated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS memory_assets (
    memory_id         TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    sort_index        INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (memory_id, asset_id)
);

-- ============================================================
-- ACTIVITY LOG
-- ============================================================

CREATE TABLE IF NOT EXISTS activity_log (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    album_id          TEXT REFERENCES albums(id) ON DELETE CASCADE,
    asset_id          TEXT REFERENCES assets(id) ON DELETE SET NULL,
    action            TEXT NOT NULL,
    comment_text      TEXT,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_activity_album ON activity_log(album_id, created_at DESC);

-- ============================================================
-- DUPLICATE DETECTION
-- ============================================================

CREATE TABLE IF NOT EXISTS duplicate_groups (
    id                TEXT PRIMARY KEY,
    owner_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status            TEXT NOT NULL DEFAULT 'pending',
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS duplicate_group_assets (
    group_id          TEXT NOT NULL REFERENCES duplicate_groups(id) ON DELETE CASCADE,
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    is_primary        INTEGER NOT NULL DEFAULT 0,
    similarity_score  REAL,
    PRIMARY KEY (group_id, asset_id)
);

-- ============================================================
-- BACKGROUND JOBS
-- ============================================================

CREATE TABLE IF NOT EXISTS jobs (
    id                TEXT PRIMARY KEY,
    job_type          TEXT NOT NULL,
    asset_id          TEXT REFERENCES assets(id) ON DELETE CASCADE,
    status            TEXT NOT NULL DEFAULT 'pending',
    priority          INTEGER NOT NULL DEFAULT 5,
    attempts          INTEGER NOT NULL DEFAULT 0,
    max_attempts      INTEGER NOT NULL DEFAULT 3,
    error_message     TEXT,
    started_at        TEXT,
    completed_at      TEXT,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status, priority, created_at) WHERE status IN ('pending', 'retry');

-- ============================================================
-- SERVER SETTINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS server_settings (
    key               TEXT PRIMARY KEY,
    value             TEXT NOT NULL,
    updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Default settings
INSERT OR IGNORE INTO server_settings (key, value) VALUES
    ('ml_enabled', 'true'),
    ('ml_face_recognition', 'true'),
    ('ml_clip_search', 'true'),
    ('ml_ocr', 'true'),
    ('storage_backend', 'filesystem'),
    ('trash_auto_delete_days', '30'),
    ('default_storage_quota', '0'),
    ('registration_enabled', 'false'),
    ('server_name', 'Reframe'),
    ('map_tile_provider', 'osm'),
    ('schema_version', '1');
