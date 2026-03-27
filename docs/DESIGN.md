# Reframe — Design Document

**Version:** 1.0
**Date:** March 27, 2026
**Author:** Ryan / Summit Software Solutions LLC
**License:** MIT
**Repository:** github.com/[TBD]/reframe

---

## 1. Executive Summary

Reframe is an open-source, self-hosted alternative to Google Photos. It provides full photo and video backup, AI-powered search, face recognition, timeline browsing, map view, memories, and sharing — all running on your own hardware with no cloud dependency required.

### Core Principles

- **Your data, your server.** No vendor lock-in, no subscription fees, no data mining.
- **Google Photos parity.** Not a toy — a real replacement that handles the full lifecycle of photo/video management.
- **Household-first.** Designed for 2–10 users sharing a family photo library, not enterprise scale.
- **Local-first AI.** Face recognition, visual search, and OCR run locally by default. No photos leave your network unless you opt in.
- **One-command deploy.** Docker Compose up and running in under 5 minutes.
- **Plugin-extensible.** Open API for community-built integrations (editors, AI upscalers, export targets).

### Target Users

- Privacy-conscious individuals and families replacing Google Photos / iCloud Photos
- Self-hosters with a NAS, Raspberry Pi, or home server
- Photographers who want RAW file support and EXIF browsing
- Anyone who wants control over their photo library without a monthly fee

---

## 2. Technology Stack

### 2.1 Backend — Go

**Why Go:** Exceptional concurrency model for handling simultaneous uploads, thumbnail generation, and video transcoding. Low memory footprint critical for self-hosted environments (NAS, Raspberry Pi). Single binary deployment. Strong standard library for HTTP servers and file I/O.

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| HTTP Framework | Gin or Echo | Lightweight, fast, middleware-friendly |
| Database | SQLite (via go-sqlite3 or modernc.org/sqlite) | Zero-config, single-file, self-host friendly |
| Job Queue | Asynq (Redis-backed) or in-process queue | Background thumbnail gen, transcoding, ML jobs |
| Storage Abstraction | Custom interface (see §5) | Supports local filesystem + S3-compatible |
| Video Transcoding | FFmpeg (via CLI orchestration) | Industry standard, handles all codecs |
| Image Processing | libvips (via govips) | 8x faster than ImageMagick, low memory |
| RAW Processing | LibRaw / dcraw (via CLI) | Handles CR2, NEF, ARW, DNG |
| EXIF Parsing | goexif or rwcarlsen/goexif | Native Go EXIF extraction |
| Auth | JWT (golang-jwt/jwt) | Stateless, simple |
| WebSocket | gorilla/websocket | Real-time sync notifications |
| Config | Viper | Environment vars + config file support |

### 2.2 ML Sidecar — Python

**Why a separate service:** ML dependencies (PyTorch, ONNX, etc.) are large and Python-specific. Running as a sidecar allows the Go backend to remain lean. The ML service can be disabled entirely on low-power hardware, with graceful degradation (search by metadata only, no face recognition).

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Framework | FastAPI | Async, fast, OpenAPI docs built-in |
| Face Recognition | InsightFace / ArcFace (ONNX) | State-of-the-art accuracy, runs locally |
| Visual Search | OpenAI CLIP (ViT-B/32 via ONNX) | Search "beach" and find beaches — no tagging |
| OCR | Tesseract (via pytesseract) | Extract text from scanned docs/screenshots |
| Image Embeddings | CLIP → stored as vectors in SQLite | Similarity search via cosine distance |
| Face Embeddings | ArcFace → stored as vectors in SQLite | Face clustering and matching |
| Model Runtime | ONNX Runtime | CPU-optimized, GPU optional |
| Task Queue | Celery + Redis (shared with Go) or direct API | Async ML processing |

**Graceful degradation:** If the ML sidecar is unreachable or disabled, the Go backend continues to function. Search falls back to filename/date/EXIF metadata. Face recognition features are hidden in the UI. A health check endpoint reports ML status to the frontend.

### 2.3 Mobile — React Native

**Why React Native:** True native background upload on both iOS and Android. Single codebase for both platforms. Large ecosystem. Expo can be used for faster iteration but eject capability is available for native module access.

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Framework | React Native (Expo managed → bare if needed) | Cross-platform, background upload support |
| Navigation | React Navigation v7 | Standard RN navigation |
| State Management | Zustand | Lightweight, simple |
| Background Upload | react-native-background-upload | True background sync on iOS + Android |
| Background Fetch | react-native-background-fetch | Periodic sync triggers |
| Photo Access | react-native-cameraroll / expo-media-library | Access device photo library |
| Offline Storage | WatermelonDB or MMKV | Fast local cache for thumbnails/metadata |
| Image Display | react-native-fast-image | Cached, performant image loading |
| Video Playback | react-native-video | Streaming playback |
| QR Code | react-native-qrcode-svg + react-native-camera | Generate and scan share QR codes |
| Biometrics | react-native-biometrics | Locked folder PIN/biometric |
| File System | react-native-fs | Local thumbnail cache |
| Networking | Axios + WebSocket | API calls + real-time sync |

### 2.4 Web Client — React

A responsive web interface for desktop/laptop access. Shares component logic with React Native where possible via shared TypeScript packages.

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Framework | React 18+ with TypeScript | Shared mental model with RN |
| Build Tool | Vite | Fast dev, optimized builds |
| Routing | React Router v6 | Standard |
| State | Zustand (shared with RN) | Consistent state management |
| UI Components | Tailwind CSS + Radix UI primitives | Accessible, customizable |
| Image Grid | react-virtuoso or react-window | Virtualized for 100K+ photos |
| Map | Leaflet + react-leaflet (or Mapbox) | Free, open-source map tiles |
| Video | HLS.js | Adaptive streaming |
| PWA | Vite PWA plugin | Installable, service worker caching |

### 2.5 Infrastructure

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Database | SQLite 3.40+ (WAL mode) | Single file, no server process |
| Cache/Queue | Redis (optional) or in-process | Job queue for background tasks |
| Reverse Proxy | Caddy or Traefik (in Docker Compose) | Auto HTTPS, simple config |
| Container | Docker + Docker Compose | One-command deployment |
| Video Transcoding | FFmpeg 6+ | Hardware acceleration support (VAAPI, NVENC) |
| Image Processing | libvips 8.14+ | Fast thumbnail generation |
| Object Storage | Local filesystem / MinIO / S3 / Backblaze B2 | Configurable via storage abstraction |

---

## 3. Architecture

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Compose                           │
│                                                                 │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────────┐  │
│  │   Caddy      │    │  Go Backend  │    │  Python ML        │  │
│  │   (Reverse   │───▶│  (API +      │───▶│  Sidecar          │  │
│  │    Proxy)    │    │   Workers)   │    │  (Face/CLIP/OCR)  │  │
│  └─────────────┘    └──────┬───────┘    └───────────────────┘  │
│                            │                                    │
│                     ┌──────┴───────┐                           │
│                     │   SQLite     │                           │
│                     │   Database   │                           │
│                     └──────┬───────┘                           │
│                            │                                    │
│                     ┌──────┴───────┐                           │
│                     │   Storage    │                           │
│                     │   Layer      │                           │
│                     │  (FS / S3)   │                           │
│                     └──────────────┘                           │
│                                                                 │
│  ┌──────────┐  (optional)                                      │
│  │  Redis   │  Job queue, caching                              │
│  └──────────┘                                                  │
└─────────────────────────────────────────────────────────────────┘

         ▲               ▲               ▲
         │               │               │
    ┌────┴───┐     ┌─────┴────┐    ┌─────┴────┐
    │ React  │     │  React   │    │  React   │
    │ Native │     │  Native  │    │  Web     │
    │ (iOS)  │     │ (Android)│    │ (Browser)│
    └────────┘     └──────────┘    └──────────┘
```

### 3.2 Service Communication

| From | To | Protocol | Purpose |
|------|----|----------|---------|
| Clients → Caddy | HTTPS | All client traffic |
| Caddy → Go Backend | HTTP (internal) | Reverse proxy |
| Go Backend → ML Sidecar | HTTP (internal) | Face/CLIP/OCR requests |
| Go Backend → Redis | TCP (internal) | Job queue, caching |
| Go Backend → SQLite | File I/O | Database operations |
| Go Backend → Storage | File I/O or S3 API | Media read/write |
| Go Backend → FFmpeg | CLI subprocess | Video transcoding |
| Go Backend → libvips | CGo bindings | Thumbnail generation |
| Go Backend → Clients | WebSocket | Real-time sync notifications |

### 3.3 Request Flow — Photo Upload

```
1. Client selects/captures photo
2. Client reads EXIF metadata locally (date, GPS, camera info)
3. Client computes file hash (SHA-256) for dedup check
4. Client → POST /api/v1/assets/check-duplicates { hash }
5. If duplicate → skip (or prompt user)
6. Client → POST /api/v1/assets/upload (multipart: file + metadata)
7. Go Backend:
   a. Validates JWT, checks storage quota
   b. Writes original to storage layer (/{user_id}/originals/{year}/{month}/{hash}.ext)
   c. Inserts asset record into SQLite (status: "processing")
   d. Enqueues background jobs:
      - generate_thumbnails (tiny: 200px, small: 400px, medium: 1200px)
      - extract_exif (if not provided by client)
      - extract_gps → reverse geocode location name
      - generate_blurhash (placeholder while loading)
      - ml_face_detect → sent to Python sidecar
      - ml_clip_embed → sent to Python sidecar
      - ml_ocr (if screenshot/document) → sent to Python sidecar
      - video_transcode (if video) → FFmpeg pipeline
   e. Returns 202 Accepted { asset_id, status: "processing" }
8. Background workers process jobs, update asset status
9. WebSocket notification → client updates UI
```

### 3.4 Request Flow — Background Sync (Mobile)

```
1. react-native-background-fetch triggers periodically (iOS: ~15min minimum)
2. App compares local photo library against sync cursor (last sync timestamp)
3. New photos identified → queued for upload
4. react-native-background-upload handles each file:
   a. Upload continues even if app is suspended
   b. Progress tracked via native upload manager
   c. On completion → update local sync state
5. If network unavailable → queue persisted locally, retried on connectivity
6. On app foreground → immediate sync check + progress UI
```

---

## 4. Data Model

### 4.1 SQLite Schema

SQLite is used in WAL (Write-Ahead Logging) mode for concurrent read access. All timestamps are stored as ISO 8601 UTC strings. UUIDs are used for all primary keys (stored as TEXT in SQLite).

```sql
-- Enable WAL mode on connection
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;

-- ============================================================
-- USERS & AUTH
-- ============================================================

CREATE TABLE users (
    id                TEXT PRIMARY KEY,           -- UUID
    username          TEXT NOT NULL UNIQUE,
    email             TEXT UNIQUE,
    password_hash     TEXT NOT NULL,              -- bcrypt
    display_name      TEXT NOT NULL,
    role              TEXT NOT NULL DEFAULT 'user', -- 'admin' | 'user'
    storage_quota_bytes INTEGER DEFAULT 0,        -- 0 = unlimited
    storage_used_bytes  INTEGER DEFAULT 0,
    is_active         INTEGER NOT NULL DEFAULT 1,
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE invite_codes (
    id                TEXT PRIMARY KEY,           -- UUID
    code              TEXT NOT NULL UNIQUE,       -- 8-char alphanumeric
    created_by        TEXT NOT NULL REFERENCES users(id),
    used_by           TEXT REFERENCES users(id),
    expires_at        TEXT,
    is_used           INTEGER NOT NULL DEFAULT 0,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE sessions (
    id                TEXT PRIMARY KEY,           -- UUID
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL,
    device_name       TEXT,
    device_type       TEXT,                       -- 'ios' | 'android' | 'web'
    last_active_at    TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at        TEXT NOT NULL,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================================
-- ASSETS (Photos, Videos, Documents)
-- ============================================================

CREATE TABLE assets (
    id                TEXT PRIMARY KEY,           -- UUID
    owner_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    file_hash         TEXT NOT NULL,              -- SHA-256 of original file
    file_name         TEXT NOT NULL,              -- Original filename
    file_size_bytes   INTEGER NOT NULL,
    mime_type         TEXT NOT NULL,              -- image/jpeg, video/mp4, etc.
    asset_type        TEXT NOT NULL,              -- 'photo' | 'video' | 'screenshot' | 'document' | 'raw'
    status            TEXT NOT NULL DEFAULT 'uploading',  -- 'uploading' | 'processing' | 'ready' | 'failed'
    width             INTEGER,                    -- Original dimensions
    height            INTEGER,
    duration_seconds  REAL,                       -- Video duration
    blurhash          TEXT,                       -- BlurHash placeholder string

    -- Storage paths (relative to storage root)
    original_path     TEXT NOT NULL,
    thumbnail_tiny    TEXT,                       -- 200px
    thumbnail_small   TEXT,                       -- 400px
    thumbnail_medium  TEXT,                       -- 1200px
    video_hls_path    TEXT,                       -- HLS manifest for transcoded video

    -- Temporal
    captured_at       TEXT,                       -- EXIF date or file creation date
    timezone          TEXT,                       -- IANA timezone if available

    -- Location
    latitude          REAL,
    longitude         REAL,
    altitude          REAL,
    location_name     TEXT,                       -- Reverse geocoded "Traverse City, MI"
    location_country  TEXT,

    -- EXIF / Metadata
    camera_make       TEXT,
    camera_model      TEXT,
    lens_model        TEXT,
    focal_length      REAL,                       -- mm
    aperture          REAL,                       -- f-number
    shutter_speed     TEXT,                       -- "1/250" as string for display
    iso               INTEGER,
    flash_fired       INTEGER,                    -- boolean
    orientation       INTEGER,                    -- EXIF orientation (1-8)
    color_space       TEXT,
    exif_json         TEXT,                       -- Full EXIF dump as JSON for detail view

    -- Organization
    is_favorite       INTEGER NOT NULL DEFAULT 0,
    is_archived       INTEGER NOT NULL DEFAULT 0,
    is_locked         INTEGER NOT NULL DEFAULT 0, -- In locked folder
    is_deleted        INTEGER NOT NULL DEFAULT 0, -- Soft delete (trash)
    deleted_at        TEXT,                       -- Auto-purge after 30 days

    -- ML Processing Status
    ml_faces_processed    INTEGER NOT NULL DEFAULT 0,
    ml_clip_processed     INTEGER NOT NULL DEFAULT 0,
    ml_ocr_processed      INTEGER NOT NULL DEFAULT 0,

    -- OCR
    ocr_text          TEXT,                       -- Extracted text from screenshots/docs

    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at        TEXT NOT NULL DEFAULT (datetime('now')),

    UNIQUE(owner_id, file_hash)                   -- Prevent duplicate uploads per user
);

CREATE INDEX idx_assets_owner_captured ON assets(owner_id, captured_at DESC);
CREATE INDEX idx_assets_owner_type ON assets(owner_id, asset_type);
CREATE INDEX idx_assets_owner_favorite ON assets(owner_id, is_favorite) WHERE is_favorite = 1;
CREATE INDEX idx_assets_owner_archived ON assets(owner_id, is_archived) WHERE is_archived = 1;
CREATE INDEX idx_assets_owner_deleted ON assets(owner_id, is_deleted) WHERE is_deleted = 1;
CREATE INDEX idx_assets_owner_locked ON assets(owner_id, is_locked) WHERE is_locked = 1;
CREATE INDEX idx_assets_location ON assets(latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX idx_assets_hash ON assets(file_hash);
CREATE INDEX idx_assets_status ON assets(status) WHERE status != 'ready';

-- ============================================================
-- FACE RECOGNITION
-- ============================================================

CREATE TABLE faces (
    id                TEXT PRIMARY KEY,           -- UUID
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    person_id         TEXT REFERENCES people(id) ON DELETE SET NULL,
    embedding         BLOB NOT NULL,              -- ArcFace 512-dim float32 vector
    bounding_box      TEXT NOT NULL,              -- JSON: {x, y, width, height} normalized 0-1
    confidence        REAL NOT NULL,              -- Detection confidence
    thumbnail_path    TEXT,                       -- Cropped face thumbnail
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_faces_asset ON faces(asset_id);
CREATE INDEX idx_faces_person ON faces(person_id);

CREATE TABLE people (
    id                TEXT PRIMARY KEY,           -- UUID
    owner_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name              TEXT,                       -- User-assigned name (nullable until identified)
    representative_face_id TEXT REFERENCES faces(id),
    merge_target_id   TEXT REFERENCES people(id), -- For merging duplicate people
    is_hidden         INTEGER NOT NULL DEFAULT 0,
    photo_count       INTEGER NOT NULL DEFAULT 0, -- Denormalized count
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_people_owner ON people(owner_id);

-- ============================================================
-- CLIP EMBEDDINGS (Visual Search)
-- ============================================================

CREATE TABLE clip_embeddings (
    asset_id          TEXT PRIMARY KEY REFERENCES assets(id) ON DELETE CASCADE,
    embedding         BLOB NOT NULL,              -- CLIP 512-dim float32 vector
    model_version     TEXT NOT NULL DEFAULT 'ViT-B/32',
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================================
-- ALBUMS
-- ============================================================

CREATE TABLE albums (
    id                TEXT PRIMARY KEY,           -- UUID
    owner_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title             TEXT NOT NULL,
    description       TEXT,
    cover_asset_id    TEXT REFERENCES assets(id) ON DELETE SET NULL,
    album_type        TEXT NOT NULL DEFAULT 'manual', -- 'manual' | 'auto' | 'shared'
    sort_order        TEXT NOT NULL DEFAULT 'captured_at_desc',
    is_shared         INTEGER NOT NULL DEFAULT 0,
    share_token       TEXT UNIQUE,                -- For link/QR sharing
    share_permissions TEXT NOT NULL DEFAULT 'view', -- 'view' | 'contribute' | 'edit'
    share_requires_auth INTEGER NOT NULL DEFAULT 0, -- Public link vs auth required
    asset_count       INTEGER NOT NULL DEFAULT 0, -- Denormalized
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_albums_owner ON albums(owner_id);
CREATE INDEX idx_albums_share_token ON albums(share_token) WHERE share_token IS NOT NULL;

CREATE TABLE album_assets (
    album_id          TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    sort_index        INTEGER NOT NULL DEFAULT 0,
    added_by          TEXT REFERENCES users(id),
    added_at          TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (album_id, asset_id)
);

CREATE INDEX idx_album_assets_asset ON album_assets(asset_id);

-- ============================================================
-- ALBUM COLLABORATORS
-- ============================================================

CREATE TABLE album_collaborators (
    album_id          TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role              TEXT NOT NULL DEFAULT 'viewer', -- 'viewer' | 'contributor' | 'editor'
    joined_at         TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (album_id, user_id)
);

-- ============================================================
-- SHARING
-- ============================================================

CREATE TABLE share_links (
    id                TEXT PRIMARY KEY,           -- UUID
    token             TEXT NOT NULL UNIQUE,        -- URL-safe random token
    created_by        TEXT NOT NULL REFERENCES users(id),
    share_type        TEXT NOT NULL,              -- 'asset' | 'album' | 'multi_asset'
    target_id         TEXT NOT NULL,              -- asset_id or album_id
    permissions       TEXT NOT NULL DEFAULT 'view', -- 'view' | 'download' | 'contribute'
    requires_auth     INTEGER NOT NULL DEFAULT 0,
    password_hash     TEXT,                       -- Optional password protection
    max_views         INTEGER,                    -- Optional view limit
    view_count        INTEGER NOT NULL DEFAULT 0,
    expires_at        TEXT,
    is_active         INTEGER NOT NULL DEFAULT 1,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_share_links_token ON share_links(token);
CREATE INDEX idx_share_links_target ON share_links(share_type, target_id);

-- For sharing multiple individual assets via a single link
CREATE TABLE share_link_assets (
    share_link_id     TEXT NOT NULL REFERENCES share_links(id) ON DELETE CASCADE,
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    PRIMARY KEY (share_link_id, asset_id)
);

-- ============================================================
-- PARTNER SHARING
-- ============================================================

CREATE TABLE partner_sharing (
    id                TEXT PRIMARY KEY,           -- UUID
    from_user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    share_mode        TEXT NOT NULL DEFAULT 'all', -- 'all' | 'by_person'
    is_active         INTEGER NOT NULL DEFAULT 1,
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(from_user_id, to_user_id)
);

-- Which people (faces) to auto-share with partner
CREATE TABLE partner_sharing_people (
    partner_sharing_id TEXT NOT NULL REFERENCES partner_sharing(id) ON DELETE CASCADE,
    person_id          TEXT NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    PRIMARY KEY (partner_sharing_id, person_id)
);

-- ============================================================
-- MEMORIES
-- ============================================================

CREATE TABLE memories (
    id                TEXT PRIMARY KEY,           -- UUID
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    memory_type       TEXT NOT NULL,              -- 'on_this_day' | 'recent_highlight' | 'trip' | 'people'
    title             TEXT NOT NULL,
    description       TEXT,
    date_reference    TEXT,                       -- The date this memory references
    is_seen           INTEGER NOT NULL DEFAULT 0,
    is_dismissed      INTEGER NOT NULL DEFAULT 0,
    generated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE memory_assets (
    memory_id         TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    sort_index        INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (memory_id, asset_id)
);

-- ============================================================
-- ACTIVITY LOG (Shared Album Activity)
-- ============================================================

CREATE TABLE activity_log (
    id                TEXT PRIMARY KEY,           -- UUID
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    album_id          TEXT REFERENCES albums(id) ON DELETE CASCADE,
    asset_id          TEXT REFERENCES assets(id) ON DELETE SET NULL,
    action            TEXT NOT NULL,              -- 'added_photo' | 'commented' | 'liked' | 'joined'
    comment_text      TEXT,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_activity_album ON activity_log(album_id, created_at DESC);

-- ============================================================
-- DUPLICATE DETECTION
-- ============================================================

CREATE TABLE duplicate_groups (
    id                TEXT PRIMARY KEY,           -- UUID
    owner_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status            TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'resolved' | 'dismissed'
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE duplicate_group_assets (
    group_id          TEXT NOT NULL REFERENCES duplicate_groups(id) ON DELETE CASCADE,
    asset_id          TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    is_primary        INTEGER NOT NULL DEFAULT 0, -- Suggested "keep" version
    similarity_score  REAL,
    PRIMARY KEY (group_id, asset_id)
);

-- ============================================================
-- BACKGROUND JOBS
-- ============================================================

CREATE TABLE jobs (
    id                TEXT PRIMARY KEY,           -- UUID
    job_type          TEXT NOT NULL,              -- 'thumbnail' | 'transcode' | 'face_detect' | 'clip_embed' | 'ocr' | 'geocode' | 'dedup'
    asset_id          TEXT REFERENCES assets(id) ON DELETE CASCADE,
    status            TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'running' | 'completed' | 'failed' | 'retry'
    priority          INTEGER NOT NULL DEFAULT 5, -- 1 (highest) to 10 (lowest)
    attempts          INTEGER NOT NULL DEFAULT 0,
    max_attempts      INTEGER NOT NULL DEFAULT 3,
    error_message     TEXT,
    started_at        TEXT,
    completed_at      TEXT,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_jobs_status ON jobs(status, priority, created_at) WHERE status IN ('pending', 'retry');

-- ============================================================
-- SERVER SETTINGS
-- ============================================================

CREATE TABLE server_settings (
    key               TEXT PRIMARY KEY,
    value             TEXT NOT NULL,
    updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Default settings inserted on first run
-- ml_enabled: true
-- ml_face_recognition: true
-- ml_clip_search: true
-- ml_ocr: true
-- storage_backend: 'filesystem'  -- 'filesystem' | 's3'
-- s3_endpoint: ''
-- s3_bucket: ''
-- s3_access_key: ''
-- s3_secret_key: ''
-- trash_auto_delete_days: 30
-- default_storage_quota: 0  -- 0 = unlimited
-- registration_enabled: false  -- Only invite codes
-- server_name: 'Reframe'
-- map_tile_provider: 'osm'  -- 'osm' | 'mapbox'
```

---

## 5. Storage Architecture

### 5.1 Storage Abstraction Layer

The storage layer is defined as a Go interface, with two implementations: local filesystem and S3-compatible.

```go
type StorageBackend interface {
    // Write stores a file and returns the storage path
    Write(ctx context.Context, path string, reader io.Reader, contentType string) error

    // Read returns a reader for the file at the given path
    Read(ctx context.Context, path string) (io.ReadCloser, error)

    // Delete removes a file
    Delete(ctx context.Context, path string) error

    // Exists checks if a file exists
    Exists(ctx context.Context, path string) (bool, error)

    // GetURL returns a URL for direct client access (signed URL for S3, local path for FS)
    GetURL(ctx context.Context, path string, expiry time.Duration) (string, error)

    // GetSize returns the file size in bytes
    GetSize(ctx context.Context, path string) (int64, error)
}
```

### 5.2 Directory Structure (Filesystem Backend)

```
/data/
├── originals/
│   └── {user_id}/
│       └── {year}/
│           └── {month}/
│               ├── {asset_id}.jpg
│               ├── {asset_id}.cr2
│               └── {asset_id}.mp4
├── thumbnails/
│   └── {user_id}/
│       └── {asset_id}/
│           ├── tiny.webp        (200px, ~5KB)
│           ├── small.webp       (400px, ~15KB)
│           └── medium.webp      (1200px, ~80KB)
├── faces/
│   └── {user_id}/
│       └── {face_id}.webp       (Cropped face thumbnails)
├── video/
│   └── {user_id}/
│       └── {asset_id}/
│           ├── manifest.m3u8    (HLS manifest)
│           ├── 720p/
│           │   └── segment_*.ts
│           └── 1080p/
│               └── segment_*.ts
├── exports/                     (Temporary export ZIPs)
├── temp/                        (Upload staging)
└── database/
    └── reframe.db               (SQLite database file)
```

### 5.3 Thumbnail Pipeline

All thumbnails are generated as WebP for optimal size/quality ratio. Original files are never modified.

| Tier | Max Dimension | Quality | Use Case | Approx Size |
|------|--------------|---------|----------|-------------|
| Tiny | 200px | 70% | Grid view (dozens visible) | 3–8 KB |
| Small | 400px | 75% | Preview / hover | 10–25 KB |
| Medium | 1200px | 85% | Detail view / sharing | 50–120 KB |
| Original | N/A | N/A | Download / edit | Varies |
| BlurHash | N/A | N/A | Placeholder while loading | ~30 bytes |

**RAW file handling:** LibRaw extracts embedded preview JPEGs first (fast). Full RAW decode is used only if no embedded preview exists or for medium/original quality.

**Video thumbnails:** FFmpeg extracts a frame at 10% duration for the thumbnail. Animated thumbnails (3-second GIF/WebP loops) are generated as a stretch goal.

### 5.4 Video Transcoding Pipeline

Videos are transcoded to HLS (HTTP Live Streaming) for adaptive bitrate streaming across all devices.

```
FFmpeg Pipeline:
1. Probe: Extract codec, resolution, duration, rotation
2. Thumbnail: Extract frame at ~10% duration
3. Transcode to HLS:
   - 720p  @ 2500 kbps (baseline for all devices)
   - 1080p @ 5000 kbps (if source >= 1080p)
   - Original resolution kept if source > 1080p
   - Audio: AAC 128kbps stereo
   - Segment duration: 6 seconds
4. Generate master manifest (m3u8)
5. Hardware acceleration: VAAPI (Intel), NVENC (NVIDIA) if available, fallback to software
```

**Transcoding is async.** Videos are playable immediately via direct file serving (original format). HLS versions become available as transcoding completes.

---

## 6. API Design

### 6.1 API Conventions

- Base URL: `/api/v1/`
- Authentication: Bearer JWT in Authorization header
- Content-Type: `application/json` (except uploads: `multipart/form-data`)
- Pagination: cursor-based using `?cursor={id}&limit={n}` (default limit: 50, max: 200)
- Errors: `{ "error": { "code": "NOT_FOUND", "message": "Asset not found" } }`
- Dates: ISO 8601 UTC
- IDs: UUIDs

### 6.2 Authentication Endpoints

```
POST   /api/v1/auth/register          Register with invite code
POST   /api/v1/auth/login             Login → returns access + refresh tokens
POST   /api/v1/auth/refresh           Refresh access token
POST   /api/v1/auth/logout            Invalidate refresh token
GET    /api/v1/auth/me                Get current user profile
PUT    /api/v1/auth/me                Update profile (display name, email)
PUT    /api/v1/auth/me/password       Change password
```

**Register payload:**
```json
{
  "invite_code": "ABC12345",
  "username": "ryan",
  "password": "...",
  "display_name": "Ryan",
  "email": "ryan@example.com"       // optional
}
```

**Login response:**
```json
{
  "access_token": "eyJ...",          // JWT, 15min expiry
  "refresh_token": "eyJ...",         // JWT, 30 day expiry
  "user": {
    "id": "uuid",
    "username": "ryan",
    "display_name": "Ryan",
    "role": "admin"
  }
}
```

### 6.3 Asset Endpoints

```
POST   /api/v1/assets/upload          Upload single asset (multipart)
POST   /api/v1/assets/upload/batch    Upload multiple assets
POST   /api/v1/assets/check-duplicate Check if hash exists
GET    /api/v1/assets                 List assets (timeline, filterable)
GET    /api/v1/assets/:id             Get single asset details + full EXIF
GET    /api/v1/assets/:id/original    Stream/download original file
GET    /api/v1/assets/:id/thumbnail/:size  Get thumbnail (tiny|small|medium)
GET    /api/v1/assets/:id/video       Stream HLS video
PUT    /api/v1/assets/:id             Update asset metadata
PUT    /api/v1/assets/:id/favorite    Toggle favorite
PUT    /api/v1/assets/:id/archive     Toggle archive
PUT    /api/v1/assets/:id/lock        Move to/from locked folder
DELETE /api/v1/assets/:id             Move to trash (soft delete)
POST   /api/v1/assets/:id/restore     Restore from trash
DELETE /api/v1/assets/:id/permanent   Permanent delete
POST   /api/v1/assets/bulk            Bulk operations (favorite, archive, delete, add to album)
```

**Timeline query parameters:**
```
GET /api/v1/assets?
  cursor=uuid             -- Pagination cursor
  limit=50                -- Results per page
  type=photo|video|screenshot|document|raw  -- Filter by type
  favorite=true           -- Only favorites
  archived=true           -- Only archived
  locked=true             -- Only locked folder (requires PIN verification)
  deleted=true            -- Trash view
  from=2025-01-01         -- Date range start
  to=2025-12-31           -- Date range end
  person_id=uuid          -- Photos of a specific person
  album_id=uuid           -- Photos in a specific album
  location_lat=42.5       -- Near a location
  location_lng=-83.3
  location_radius=10      -- Radius in km
```

### 6.4 Search Endpoints

```
POST   /api/v1/search                 Unified search (text → CLIP + metadata)
GET    /api/v1/search/suggestions     Search suggestions / autocomplete
```

**Search payload:**
```json
{
  "query": "beach sunset",
  "filters": {
    "type": ["photo", "video"],
    "date_from": "2024-01-01",
    "date_to": "2025-12-31",
    "person_ids": ["uuid1", "uuid2"],
    "location": {
      "lat": 42.5,
      "lng": -83.3,
      "radius_km": 50
    }
  },
  "limit": 50,
  "cursor": "..."
}
```

**Search implementation:**
1. Query is sent to ML sidecar → CLIP text embedding generated
2. Cosine similarity search against all clip_embeddings
3. Results merged with metadata search (filename, location_name, OCR text)
4. Combined ranking: `0.7 * clip_score + 0.3 * metadata_score`
5. Filtered by user permissions (own assets + partner-shared assets)

### 6.5 People / Face Recognition Endpoints

```
GET    /api/v1/people                 List all recognized people
GET    /api/v1/people/:id             Get person details + photo count
PUT    /api/v1/people/:id             Update person (name, visibility)
POST   /api/v1/people/:id/merge       Merge two people
GET    /api/v1/people/:id/assets      Get all assets containing this person
POST   /api/v1/people/unassign        Remove a face from a person
POST   /api/v1/faces/:id/assign       Assign a face to a person
GET    /api/v1/faces/unassigned       Get unassigned face clusters for review
```

### 6.6 Album Endpoints

```
POST   /api/v1/albums                 Create album
GET    /api/v1/albums                 List user's albums
GET    /api/v1/albums/:id             Get album details + assets
PUT    /api/v1/albums/:id             Update album metadata
DELETE /api/v1/albums/:id             Delete album (assets remain)
POST   /api/v1/albums/:id/assets      Add assets to album
DELETE /api/v1/albums/:id/assets       Remove assets from album
PUT    /api/v1/albums/:id/cover       Set cover photo
POST   /api/v1/albums/:id/share       Generate share link/QR
DELETE /api/v1/albums/:id/share       Revoke share link
POST   /api/v1/albums/:id/collaborators  Add collaborator
DELETE /api/v1/albums/:id/collaborators/:user_id  Remove collaborator
GET    /api/v1/albums/:id/activity     Get activity feed
```

### 6.7 Sharing Endpoints

```
POST   /api/v1/share                  Create share link (asset or album)
GET    /api/v1/share/:token           Access shared content (public endpoint)
GET    /api/v1/share/:token/qr        Get QR code image for share link
DELETE /api/v1/share/:token           Revoke share link
GET    /api/v1/share/mine             List all my active share links
```

**Share link response (public):**
```json
{
  "type": "album",
  "title": "Summer 2025",
  "owner_name": "Ryan",
  "permissions": "view",
  "assets": [
    {
      "id": "uuid",
      "thumbnail_url": "/api/v1/share/{token}/assets/{id}/thumbnail/small",
      "type": "photo",
      "captured_at": "2025-07-15T14:30:00Z"
    }
  ],
  "total_count": 47,
  "cursor": "..."
}
```

### 6.8 Partner Sharing Endpoints

```
POST   /api/v1/partner-sharing         Set up partner sharing
GET    /api/v1/partner-sharing         Get partner sharing status
PUT    /api/v1/partner-sharing/:id     Update sharing rules (which people)
DELETE /api/v1/partner-sharing/:id     Disable partner sharing
GET    /api/v1/partner-sharing/feed    Get partner-shared assets
```

### 6.9 Memories Endpoints

```
GET    /api/v1/memories                Get current memories (today)
GET    /api/v1/memories/:id            Get memory details
PUT    /api/v1/memories/:id/dismiss    Dismiss a memory
```

### 6.10 Duplicates Endpoints

```
GET    /api/v1/duplicates              List duplicate groups
PUT    /api/v1/duplicates/:id/resolve  Resolve (keep primary, delete rest)
PUT    /api/v1/duplicates/:id/dismiss  Dismiss (not duplicates)
```

### 6.11 Admin Endpoints

```
GET    /api/v1/admin/users             List all users
PUT    /api/v1/admin/users/:id         Update user (quota, role, active)
DELETE /api/v1/admin/users/:id         Deactivate user
POST   /api/v1/admin/invite-codes      Generate invite code(s)
GET    /api/v1/admin/invite-codes      List invite codes
DELETE /api/v1/admin/invite-codes/:id  Revoke invite code
GET    /api/v1/admin/server/stats      Server stats (storage, users, assets)
GET    /api/v1/admin/server/settings   Get server settings
PUT    /api/v1/admin/server/settings   Update server settings
GET    /api/v1/admin/server/jobs       View background job queue
POST   /api/v1/admin/server/jobs/retry Retry failed jobs
GET    /api/v1/admin/server/health     Health check (DB, storage, ML sidecar)
```

### 6.12 Sync Endpoints (Mobile)

```
GET    /api/v1/sync/status             Get sync cursor + stats
POST   /api/v1/sync/changes            Get changes since cursor (for offline sync)
```

### 6.13 Plugin / Extension API

```
GET    /api/v1/plugins                 List installed plugins
POST   /api/v1/plugins/:id/execute     Execute plugin action on asset(s)
GET    /api/v1/plugins/:id/callback    Plugin callback URL for returning edited assets
```

### 6.14 WebSocket

```
WS     /api/v1/ws                      Real-time events
```

**Events pushed to client:**
```json
{ "type": "asset.ready", "asset_id": "uuid" }
{ "type": "asset.faces_detected", "asset_id": "uuid", "face_count": 3 }
{ "type": "job.progress", "job_type": "transcode", "asset_id": "uuid", "percent": 45 }
{ "type": "memory.new", "memory_id": "uuid" }
{ "type": "partner.new_asset", "asset_id": "uuid", "from_user": "Krysta" }
{ "type": "share.new_activity", "album_id": "uuid", "action": "added_photo" }
{ "type": "sync.upload_complete", "asset_id": "uuid" }
```

---

## 7. Feature Specifications

### 7.1 Timeline View

The primary view. Displays all photos and videos in reverse chronological order, grouped by date.

**Behavior:**
- Virtualized grid (only renders visible items + buffer)
- Grouped by date with sticky date headers ("July 15, 2025", "Today", "Yesterday")
- Pinch-to-zoom on mobile changes grid density (3, 5, 7 columns)
- Mouse wheel zoom on web changes grid density
- Scroll position preserved on navigation
- BlurHash placeholders while thumbnails load
- Tiny thumbnails for grid, Medium thumbnail on tap/click to preview
- Long-press (mobile) or hover+checkbox (web) for multi-select
- Pull-to-refresh triggers sync check

**Filters:**
- All / Photos / Videos / Screenshots / Documents / RAW
- Favorites only
- By person (face)
- By location
- Date range

### 7.2 Asset Detail View

Full-screen view of a single asset with swipe navigation.

**Photo Detail:**
- Pinch-to-zoom with smooth animation
- Swipe left/right between assets
- Top bar: back, favorite, share, overflow menu (archive, lock, delete, info)
- Bottom sheet: EXIF details panel
  - Camera: Make, Model, Lens
  - Settings: f/2.8, 1/250s, ISO 400, 24mm
  - File: 4032x3024, 8.2 MB, JPEG
  - Location: Map pin + address
  - Date: Captured + uploaded
  - People: Face thumbnails with names
  - Full EXIF data expandable

**Video Detail:**
- HLS adaptive streaming player
- Standard controls (play/pause, seek, fullscreen, volume)
- Scrub thumbnails on seek bar
- Same metadata panel as photos + duration, codec, bitrate

### 7.3 Map View

Interactive map showing photo locations.

**Implementation:**
- Leaflet with OpenStreetMap tiles (free, no API key)
- Clustered markers at zoom-out levels (MarkerCluster)
- Individual photo markers at zoom-in levels
- Tapping a cluster shows grid of photos in that area
- Tapping a photo opens detail view
- Heatmap overlay option for dense areas
- Date range filter on map
- "Photos near here" contextual search

### 7.4 Memories

"On this day" style memories surfaced daily.

**Generation (cron job, runs daily at 6 AM user local time):**
1. Query assets from this date in previous years (1yr, 2yr, 3yr, etc.)
2. If 3+ assets found for a year, create a memory
3. Title: "X years ago" or "This day in 2023"
4. Select best 10–20 photos (prefer favorites, people photos, high-quality)
5. Avoid duplicate memories (don't resurface dismissed ones)

**Display:**
- Card carousel at top of timeline view
- Tap to expand into full-screen slideshow with transitions
- Share memory as a collage or album link
- Dismiss to hide

### 7.5 Face Recognition

Automatic face detection and clustering.

**Pipeline:**
1. **Detection:** InsightFace SCRFD model detects faces + bounding boxes
2. **Alignment:** ArcFace-aligned face crop generated
3. **Embedding:** ArcFace model generates 512-dim embedding vector
4. **Clustering:** DBSCAN or Chinese Whispers on embeddings → groups of same person
5. **Assignment:** New faces compared against existing people → auto-assigned if confidence > 0.7
6. **Review:** Unassigned faces presented to user for manual identification

**UI:**
- People grid (thumbnail mosaic per person)
- Name assignment (tap unnamed person → type name)
- Face review queue (confirm/reject auto-assignments)
- Merge people (combine mistakenly split clusters)
- Hide person (exclude from people view)
- Search by person name → shows all their photos

### 7.6 Visual Search (CLIP)

Search photos by natural language description.

**How it works:**
1. On upload, each photo is processed by CLIP ViT-B/32 → 512-dim embedding stored
2. On search, query text is encoded by CLIP text encoder → 512-dim text embedding
3. Cosine similarity between text embedding and all photo embeddings
4. Top-K results returned, ranked by similarity

**Search queries that work:**
- Objects: "dog", "car", "food", "sunset"
- Scenes: "beach vacation", "birthday party", "snowy mountain"
- Activities: "hiking", "cooking", "playing guitar"
- Colors/mood: "blue sky", "dark moody photo"
- Combinations: "red car on highway", "baby in high chair"
- OCR text is also searched for screenshots/documents

### 7.7 Sharing

**Link Sharing:**
1. User selects asset(s) or album → "Share" → generates unique token URL
2. URL format: `https://{server}/share/{token}`
3. QR code generated from URL (rendered as SVG, downloadable as PNG)
4. Options: view only / allow download / allow contribute / password protect / expiry date
5. Recipients access via browser — no account required (unless share_requires_auth)
6. Shared view: gallery grid with download button, no editing controls

**QR Code Sharing:**
- QR code displayed in-app for scanning
- Use case: showing someone your phone → they scan → open shared album on their phone
- QR encodes the share URL

**Shared Albums:**
- Album owner invites collaborators (by username or invite link)
- Contributors can add photos to album
- Activity feed shows who added what and when
- Notifications for new activity

### 7.8 Partner Sharing

Automatic sharing of specific people's photos with your partner.

**Setup:**
1. User A enables partner sharing → selects partner (User B)
2. Selects which people to share: "All" or specific people (e.g., "share all photos of the kids")
3. New photos matching selected people are automatically visible to partner
4. Partner sees these in a "Partner's photos" section
5. Partner can save to their own library (copies asset, counted against their quota)

### 7.9 Favorites, Archive, Locked Folder

**Favorites:** Simple toggle. Heart icon. Filterable in timeline.

**Archive:** Removes from main timeline but remains searchable and in albums. Accessible via Archive view.

**Locked Folder:**
- Protected by PIN code (set per user) or device biometric (mobile)
- Photos in locked folder are excluded from: timeline, search, memories, map, partner sharing
- Locked folder assets are stored in the same location but flagged `is_locked = 1`
- PIN stored as bcrypt hash on the user record
- Accessing locked folder requires PIN/biometric every time

### 7.10 Duplicate Detection

**Detection methods:**
1. **Exact duplicates:** Same SHA-256 file hash (caught on upload)
2. **Perceptual duplicates:** Similar photos from burst mode, slight edits, re-saves
   - Use pHash (perceptual hashing) or CLIP embedding similarity > 0.95
   - Compare within user's library, same date window (±1 hour)

**Resolution UI:**
- Shows duplicate groups with side-by-side comparison
- Highlights differences (resolution, file size, quality)
- Suggests "best" version (highest resolution, largest file)
- Bulk resolve: keep best, trash others

### 7.11 Storage Dashboard

Per-user and admin-level storage visibility.

**User Dashboard:**
- Total storage used / quota
- Breakdown by type: Photos, Videos, RAW, Documents, Thumbnails
- Breakdown by year
- Largest files list
- Duplicate space savings potential

**Admin Dashboard:**
- Total server storage used / available
- Per-user breakdown
- Growth trend over time
- Job queue status (pending, processing, failed)
- ML sidecar health

### 7.12 Trash / Recycle Bin

- Deleted assets move to trash (`is_deleted = 1, deleted_at = now`)
- Trash items visible in Trash view
- Restore: returns to original location in timeline
- Auto-purge: cron job deletes items older than 30 days (configurable)
- Permanent delete: removes from storage immediately, irreversible

### 7.13 Plugin / Extension System

Open API for community-built integrations.

**Plugin Types:**
1. **Editor plugins:** Send asset to external tool, receive edited version back
   - Example: Photopea (browser-based), Remove.bg, AI upscaler
2. **Export plugins:** Export to external services
   - Example: Flickr, SmugMug, social media
3. **Import plugins:** Import from external sources
   - Example: Google Takeout importer, iCloud importer
4. **Processing plugins:** Run custom processing on assets
   - Example: Watermark, custom ML model, metadata enrichment

**Plugin Manifest (JSON):**
```json
{
  "id": "photopea-editor",
  "name": "Photopea Editor",
  "version": "1.0.0",
  "type": "editor",
  "description": "Edit photos in Photopea (browser-based Photoshop alternative)",
  "author": "Community",
  "entry_url": "https://www.photopea.com",
  "accepts": ["image/jpeg", "image/png", "image/webp"],
  "returns": ["image/jpeg", "image/png"],
  "icon": "photopea-icon.svg"
}
```

**Plugin execution flow:**
1. User selects asset → "Edit with Photopea"
2. Backend generates temporary signed URL for the asset
3. Plugin opens in iframe or new tab with asset URL
4. On save, plugin POSTs edited file to callback URL
5. Backend creates new asset version (original preserved)

---

## 8. Security

### 8.1 Authentication

- Passwords hashed with bcrypt (cost 12)
- JWT access tokens: 15-minute expiry, RS256 signing
- Refresh tokens: 30-day expiry, stored hashed in DB, rotated on use
- Failed login rate limiting: 5 attempts per 10 minutes per IP
- Session management: users can view and revoke active sessions

### 8.2 Authorization

| Role | Capabilities |
|------|-------------|
| Admin | Full server management, user CRUD, invite code generation, settings |
| User | Own assets CRUD, album CRUD, share links, partner sharing |
| Share viewer | View shared content only (no auth required if public link) |

### 8.3 Data Protection

- All external traffic over HTTPS (Caddy auto-provisions Let's Encrypt certs)
- Internal service communication over Docker network (not exposed)
- SQLite database encrypted at rest with SQLCipher (optional, configurable)
- Locked folder assets: same storage, access gated by PIN verification endpoint
- Share tokens: cryptographically random, 22-character URL-safe base64
- No telemetry, no analytics, no external API calls unless user opts in

### 8.4 Input Validation

- All file uploads scanned for MIME type verification (magic bytes, not extension)
- Maximum upload size configurable (default: 500MB per file for video, 100MB for photos)
- Path traversal protection on all file operations
- SQL injection protection via parameterized queries
- XSS protection via Content-Security-Policy headers

---

## 9. Deployment

### 9.1 Docker Compose (Primary)

```yaml
version: '3.8'

services:
  reframe:
    image: reframe/reframe:latest
    container_name: reframe-server
    restart: unless-stopped
    ports:
      - "2283:2283"
    environment:
      - REFRAME_DB_PATH=/data/database/reframe.db
      - REFRAME_STORAGE_PATH=/data
      - REFRAME_STORAGE_BACKEND=filesystem    # or 's3'
      - REFRAME_ML_URL=http://reframe-ml:8100
      - REFRAME_REDIS_URL=redis://reframe-redis:6379
      - REFRAME_JWT_SECRET=${JWT_SECRET}
      - REFRAME_ADMIN_PASSWORD=${ADMIN_PASSWORD}   # First-run admin setup
      - TZ=America/Detroit
    volumes:
      - reframe-data:/data
      - /etc/localtime:/etc/localtime:ro
    depends_on:
      - reframe-ml
      - reframe-redis

  reframe-ml:
    image: reframe/reframe-ml:latest
    container_name: reframe-ml
    restart: unless-stopped
    environment:
      - REFRAME_ML_WORKERS=2
      - REFRAME_ML_DEVICE=cpu                # or 'cuda' for GPU
    volumes:
      - reframe-models:/models               # Persist downloaded models
    deploy:
      resources:
        limits:
          memory: 4G                         # ML models need RAM

  reframe-redis:
    image: redis:7-alpine
    container_name: reframe-redis
    restart: unless-stopped
    volumes:
      - reframe-redis:/data

  # Optional: Caddy reverse proxy with auto HTTPS
  caddy:
    image: caddy:2-alpine
    container_name: reframe-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy-data:/data

volumes:
  reframe-data:
  reframe-models:
  reframe-redis:
  caddy-data:
```

### 9.2 Caddyfile

```
photos.yourdomain.com {
    reverse_proxy reframe:2283
}
```

### 9.3 First-Run Setup

1. `docker compose up -d`
2. Open `http://localhost:2283` or `https://photos.yourdomain.com`
3. Admin setup wizard:
   - Set admin username and password
   - Configure storage backend (filesystem or S3)
   - Set server name
   - Enable/disable ML features
   - Generate first invite code for household members
4. Share invite code with family

### 9.4 Hardware Requirements

| Tier | CPU | RAM | Storage | Users | Notes |
|------|-----|-----|---------|-------|-------|
| Minimum | 2 cores | 4 GB | 50 GB | 1–2 | ML processing will be slow |
| Recommended | 4 cores | 8 GB | 500 GB | 2–5 | Comfortable household use |
| Power | 6+ cores | 16 GB | 2+ TB | 5–10 | Fast ML, video transcoding |
| GPU (optional) | Any + NVIDIA GPU | 8 GB + 4 GB VRAM | 1+ TB | Any | 10x faster ML processing |

### 9.5 Supported Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| Linux x86_64 | amd64 | Primary |
| Linux ARM64 | arm64 | Supported (Raspberry Pi 4/5, NAS) |
| macOS (Docker) | amd64 / arm64 | Supported |
| Windows (Docker Desktop / WSL2) | amd64 | Supported |
| Synology NAS (Docker) | amd64 / arm64 | Community tested |
| QNAP NAS (Docker) | amd64 | Community tested |

---

## 10. Mobile App Specification

### 10.1 React Native App Structure

```
/src
├── app/                          # Navigation & screens
│   ├── (tabs)/                   # Bottom tab navigator
│   │   ├── timeline.tsx          # Main photo grid
│   │   ├── search.tsx            # Search + CLIP
│   │   ├── map.tsx               # Map view
│   │   ├── albums.tsx            # Albums list
│   │   └── profile.tsx           # Settings + storage
│   ├── asset/[id].tsx            # Photo/video detail
│   ├── album/[id].tsx            # Album detail
│   ├── people/index.tsx          # People grid
│   ├── people/[id].tsx           # Person's photos
│   ├── memories/[id].tsx         # Memory slideshow
│   ├── share/[token].tsx         # Shared content viewer
│   ├── locked-folder.tsx         # PIN-protected view
│   ├── trash.tsx                 # Trash view
│   ├── duplicates.tsx            # Duplicate resolution
│   └── admin/                    # Admin screens
│       ├── users.tsx
│       ├── settings.tsx
│       └── storage.tsx
├── components/
│   ├── PhotoGrid.tsx             # Virtualized photo grid
│   ├── AssetViewer.tsx           # Full-screen photo/video viewer
│   ├── VideoPlayer.tsx           # HLS streaming player
│   ├── ExifPanel.tsx             # Metadata bottom sheet
│   ├── ShareSheet.tsx            # Share link + QR generation
│   ├── FaceCircle.tsx            # Person thumbnail circle
│   ├── MemoryCard.tsx            # Memory carousel card
│   ├── SearchBar.tsx             # Search with suggestions
│   └── MapCluster.tsx            # Clustered map markers
├── services/
│   ├── api.ts                    # API client (Axios)
│   ├── auth.ts                   # JWT management
│   ├── sync.ts                   # Background sync orchestrator
│   ├── upload.ts                 # Background upload manager
│   ├── cache.ts                  # Offline thumbnail cache
│   └── websocket.ts              # Real-time events
├── stores/
│   ├── authStore.ts              # Auth state (Zustand)
│   ├── assetStore.ts             # Asset state + cache
│   ├── syncStore.ts              # Sync state + queue
│   └── settingsStore.ts          # User preferences
└── utils/
    ├── exif.ts                   # Client-side EXIF extraction
    ├── hash.ts                   # SHA-256 file hashing
    └── thumbnail.ts              # Local thumbnail generation
```

### 10.2 Background Sync Implementation

**iOS:**
- Use `react-native-background-fetch` for periodic sync triggers (~15 min minimum)
- Use `react-native-background-upload` (NSURLSession) for upload continuation
- Register for significant location changes to trigger sync
- iOS Background Processing tasks (BGProcessingTask) for longer sync windows

**Android:**
- Use `react-native-background-fetch` backed by WorkManager
- Use `react-native-background-upload` for upload continuation
- Foreground service notification during active sync ("Uploading 23 of 147 photos...")
- Content observer on MediaStore for new photo detection

**Sync Logic:**
1. On trigger, compare device photo library against last sync timestamp
2. New photos → add to upload queue (persisted in MMKV)
3. Upload queue processed sequentially (configurable concurrent uploads)
4. Each upload: hash check → upload original → confirm → update sync cursor
5. Failed uploads → retry with exponential backoff (max 5 retries)
6. WiFi-only mode option (default: on)
7. Battery-saver mode: pause sync below 20% battery

### 10.3 Offline Capability

- Recently viewed photo thumbnails cached locally (MMKV or filesystem)
- Cache size configurable (default: 500MB)
- LRU eviction when cache exceeds limit
- Offline indicator in UI when server unreachable
- Queued operations (favorite, archive, delete) synced on reconnect

---

## 11. Web Client Specification

### 11.1 Key Screens

| Screen | Route | Description |
|--------|-------|-------------|
| Timeline | `/` | Main photo grid, date-grouped |
| Asset Detail | `/assets/:id` | Full-screen viewer + EXIF |
| Search | `/search` | Search bar + CLIP results + filters |
| Map | `/map` | Leaflet map with clustered photos |
| Albums | `/albums` | Album grid |
| Album Detail | `/albums/:id` | Album photo grid |
| People | `/people` | People mosaic grid |
| Person Detail | `/people/:id` | Person's photos |
| Memories | `/memories` | Today's memories |
| Favorites | `/favorites` | Favorited assets |
| Archive | `/archive` | Archived assets |
| Locked Folder | `/locked` | PIN-gated assets |
| Trash | `/trash` | Deleted assets (30-day window) |
| Duplicates | `/duplicates` | Duplicate resolution |
| Shared | `/share/:token` | Public shared view (no auth) |
| Settings | `/settings` | User settings |
| Admin | `/admin` | Server admin (admin only) |
| Storage | `/admin/storage` | Storage dashboard |
| Users | `/admin/users` | User management |

### 11.2 Performance Targets

| Metric | Target | How |
|--------|--------|-----|
| Initial load | < 2s | Code splitting, lazy routes |
| Timeline scroll (10K+ photos) | 60fps | Virtualized grid (react-virtuoso) |
| Thumbnail load | < 100ms | WebP, CDN-like caching headers, BlurHash |
| Search results | < 500ms | Pre-computed CLIP embeddings, indexed |
| Photo detail open | < 200ms | Preload medium thumbnail on hover/approach |

---

## 12. Phased Roadmap

### Phase 1 — Foundation (Weeks 1–4)

**Goal:** Core upload/browse/view loop working end-to-end.

- [ ] Go backend scaffold (Gin, SQLite, config, health check)
- [ ] Storage abstraction layer (filesystem implementation)
- [ ] Auth system (register with invite code, login, JWT, refresh tokens)
- [ ] Asset upload endpoint (multipart, EXIF extraction, hash dedup)
- [ ] Thumbnail pipeline (libvips: tiny, small, medium WebP)
- [ ] BlurHash generation
- [ ] Timeline API (paginated, date-sorted)
- [ ] Background job system (in-process worker pool)
- [ ] React Native app scaffold (Expo, navigation, auth flow)
- [ ] Mobile: photo grid (virtualized, thumbnail loading)
- [ ] Mobile: asset detail view (pinch-zoom, swipe)
- [ ] Mobile: EXIF metadata panel
- [ ] Web client scaffold (Vite, React, routing, auth)
- [ ] Web: photo grid + detail view
- [ ] Docker Compose setup (Go + Redis)
- [ ] Admin: first-run setup wizard
- [ ] Admin: invite code generation

### Phase 2 — Background Sync + Video (Weeks 5–8)

**Goal:** Silent background sync on mobile. Video upload and streaming.

- [ ] Mobile: background sync service (iOS + Android)
- [ ] Mobile: upload queue with retry logic
- [ ] Mobile: sync status UI + WiFi-only toggle
- [ ] Video upload support (all common formats)
- [ ] FFmpeg transcoding pipeline (HLS, 720p + 1080p)
- [ ] Video thumbnail extraction
- [ ] HLS streaming endpoint
- [ ] Mobile: video player (react-native-video + HLS)
- [ ] Web: video player (HLS.js)
- [ ] RAW file support (LibRaw preview extraction + thumbnails)
- [ ] Screenshot and document type detection
- [ ] Storage backend: S3-compatible implementation

### Phase 3 — AI Features (Weeks 9–12)

**Goal:** Face recognition, visual search, OCR all working.

- [ ] Python ML sidecar scaffold (FastAPI, ONNX Runtime)
- [ ] Face detection pipeline (InsightFace SCRFD)
- [ ] Face embedding pipeline (ArcFace)
- [ ] Face clustering (DBSCAN)
- [ ] People management API + UI (name, merge, hide)
- [ ] CLIP embedding pipeline (ViT-B/32)
- [ ] Visual search API (text → CLIP → cosine similarity)
- [ ] Search UI (mobile + web) with results grid
- [ ] OCR pipeline (Tesseract) for screenshots + documents
- [ ] Full-text search integration (filename + location + OCR text + CLIP)
- [ ] ML health monitoring + graceful degradation

### Phase 4 — Organization + Sharing (Weeks 13–16)

**Goal:** Albums, sharing, partner sharing, favorites/archive/locked folder.

- [ ] Albums CRUD (create, edit, add/remove assets, cover photo)
- [ ] Album UI (mobile + web)
- [ ] Share link generation (token, QR code)
- [ ] Public shared view (no auth, responsive web)
- [ ] Share link management (expiry, password, revoke)
- [ ] QR code generation (SVG + PNG download)
- [ ] Partner sharing setup + auto-share by face
- [ ] Partner feed UI
- [ ] Favorites toggle + favorites view
- [ ] Archive toggle + archive view
- [ ] Locked folder (PIN setup, biometric unlock on mobile)
- [ ] Shared album collaborators + activity feed

### Phase 5 — Map, Memories, Duplicates (Weeks 17–20)

**Goal:** Map view, "on this day" memories, duplicate detection.

- [ ] Map view (Leaflet, OpenStreetMap, clustered markers)
- [ ] Reverse geocoding (Nominatim, self-hostable)
- [ ] Location-based search and filtering
- [ ] Memories generation engine (daily cron)
- [ ] Memories UI (carousel, slideshow, share)
- [ ] Duplicate detection (hash + perceptual hashing)
- [ ] Duplicate resolution UI (side-by-side, bulk resolve)
- [ ] Trash view with restore + auto-purge (30 days)
- [ ] Storage dashboard (user + admin views)

### Phase 6 — Polish + Extensions (Weeks 21–24)

**Goal:** Plugin system, performance optimization, mobile offline, admin tools.

- [ ] Plugin/extension API specification + runtime
- [ ] Google Takeout importer plugin
- [ ] Photopea editor integration plugin
- [ ] Offline photo cache (mobile)
- [ ] Admin dashboard (users, storage, jobs, health)
- [ ] User storage quota enforcement
- [ ] Rate limiting + abuse prevention
- [ ] Comprehensive logging + error reporting
- [ ] Performance optimization (query tuning, cache headers, lazy loading)
- [ ] Accessibility audit (WCAG 2.1 AA)
- [ ] Documentation: user guide, admin guide, API docs, plugin developer guide
- [ ] GitHub: README, CONTRIBUTING, issue templates, CI/CD

### Future Roadmap (Post-MVP)

- Kubernetes Helm chart
- Native Apple Watch / Wear OS companion (recent photos widget)
- Smart album suggestions ("You have 47 photos from your Traverse City trip")
- AI-generated captions and tags
- Advanced photo editing (crop, rotate, filters — built-in)
- Collage and animation maker
- Chromecast / AirPlay slideshow mode
- End-to-end encryption option (client-side encrypt before upload)
- Federation (share between multiple Reframe instances)
- Mobile widget (iOS / Android home screen memories widget)
- Apple Photos / Google Photos migration wizard
- Multi-language support (i18n)

---

## 13. Repository Structure

```
reframe/
├── README.md
├── LICENSE                          (MIT)
├── CONTRIBUTING.md
├── docker-compose.yml
├── Caddyfile
├── .env.example
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                   (Build + test)
│   │   ├── docker.yml               (Build + push images)
│   │   └── release.yml              (Semantic versioning)
│   └── ISSUE_TEMPLATE/
├── docs/
│   ├── architecture.md
│   ├── api.md                       (OpenAPI / Swagger)
│   ├── deployment.md
│   ├── plugins.md
│   └── development.md
├── server/                          (Go backend)
│   ├── go.mod
│   ├── go.sum
│   ├── main.go
│   ├── cmd/
│   │   └── server/
│   ├── internal/
│   │   ├── api/                     (HTTP handlers)
│   │   │   ├── router.go
│   │   │   ├── middleware/
│   │   │   ├── handlers/
│   │   │   │   ├── auth.go
│   │   │   │   ├── assets.go
│   │   │   │   ├── albums.go
│   │   │   │   ├── search.go
│   │   │   │   ├── people.go
│   │   │   │   ├── sharing.go
│   │   │   │   ├── memories.go
│   │   │   │   ├── admin.go
│   │   │   │   ├── sync.go
│   │   │   │   └── websocket.go
│   │   │   └── dto/                 (Request/response types)
│   │   ├── auth/                    (JWT, bcrypt, sessions)
│   │   ├── config/                  (Viper config)
│   │   ├── db/                      (SQLite, migrations)
│   │   ├── models/                  (Domain models)
│   │   ├── services/                (Business logic)
│   │   │   ├── asset_service.go
│   │   │   ├── album_service.go
│   │   │   ├── search_service.go
│   │   │   ├── people_service.go
│   │   │   ├── sharing_service.go
│   │   │   ├── memory_service.go
│   │   │   ├── sync_service.go
│   │   │   ├── duplicate_service.go
│   │   │   └── ml_client.go        (HTTP client to ML sidecar)
│   │   ├── storage/                 (Storage abstraction)
│   │   │   ├── interface.go
│   │   │   ├── filesystem.go
│   │   │   └── s3.go
│   │   ├── media/                   (Image/video processing)
│   │   │   ├── thumbnail.go        (libvips)
│   │   │   ├── exif.go
│   │   │   ├── video.go            (FFmpeg orchestration)
│   │   │   ├── raw.go              (LibRaw)
│   │   │   └── blurhash.go
│   │   ├── jobs/                    (Background job system)
│   │   │   ├── queue.go
│   │   │   ├── worker.go
│   │   │   └── handlers/
│   │   └── plugins/                 (Plugin runtime)
│   └── migrations/                  (SQL migration files)
├── ml/                              (Python ML sidecar)
│   ├── Dockerfile
│   ├── pyproject.toml
│   ├── app/
│   │   ├── main.py                  (FastAPI app)
│   │   ├── api/
│   │   │   ├── faces.py
│   │   │   ├── clip.py
│   │   │   ├── ocr.py
│   │   │   └── health.py
│   │   ├── models/                  (Model loading + inference)
│   │   │   ├── face_detector.py     (InsightFace SCRFD)
│   │   │   ├── face_embedder.py     (ArcFace)
│   │   │   ├── clip_embedder.py     (CLIP ViT-B/32)
│   │   │   └── ocr_engine.py        (Tesseract)
│   │   └── utils/
│   └── models/                      (Downloaded model weights, gitignored)
├── mobile/                          (React Native app)
│   ├── package.json
│   ├── app.json
│   ├── src/
│   │   ├── app/                     (Screens)
│   │   ├── components/
│   │   ├── services/
│   │   ├── stores/
│   │   └── utils/
│   ├── ios/
│   └── android/
├── web/                             (React web client)
│   ├── package.json
│   ├── vite.config.ts
│   ├── src/
│   │   ├── pages/
│   │   ├── components/
│   │   ├── services/
│   │   ├── stores/
│   │   └── utils/
│   └── public/
└── plugins/                         (Example/official plugins)
    ├── google-takeout-importer/
    ├── photopea-editor/
    └── plugin-template/
```

---

## 14. Development Conventions

### 14.1 Code Standards

- **Go:** `gofmt` + `golangci-lint` (standard config)
- **Python:** Black + Ruff + mypy strict
- **TypeScript/React:** ESLint + Prettier, strict TypeScript
- **Commits:** Conventional Commits (`feat:`, `fix:`, `docs:`, etc.)
- **Branching:** `main` (stable) → `develop` (integration) → `feature/*` branches

### 14.2 Testing Strategy

| Layer | Tool | Coverage Target |
|-------|------|----------------|
| Go unit tests | Go testing + testify | 80% |
| Go integration tests | testcontainers-go | Critical paths |
| Python ML tests | pytest | Model loading + inference |
| React Native | Jest + React Native Testing Library | Components + stores |
| Web | Vitest + React Testing Library | Components + stores |
| E2E | Detox (mobile) + Playwright (web) | Critical user flows |
| API | Bruno or httpyac | All endpoints |

### 14.3 CI/CD Pipeline

1. **On PR:** Lint → Unit tests → Build → Integration tests
2. **On merge to develop:** All above + E2E tests + Docker image build
3. **On release tag:** All above + Push Docker images to GitHub Container Registry + Generate changelog

---

## 15. Configuration Reference

All configuration via environment variables (12-factor app) with sensible defaults.

```bash
# === Server ===
REFRAME_HOST=0.0.0.0
REFRAME_PORT=2283
REFRAME_LOG_LEVEL=info                    # debug | info | warn | error

# === Database ===
REFRAME_DB_PATH=/data/database/reframe.db

# === Storage ===
REFRAME_STORAGE_PATH=/data
REFRAME_STORAGE_BACKEND=filesystem        # filesystem | s3
REFRAME_S3_ENDPOINT=                      # MinIO: http://minio:9000
REFRAME_S3_BUCKET=reframe
REFRAME_S3_ACCESS_KEY=
REFRAME_S3_SECRET_KEY=
REFRAME_S3_REGION=us-east-1

# === Auth ===
REFRAME_JWT_SECRET=                       # Required, auto-generated on first run if empty
REFRAME_ADMIN_PASSWORD=                   # First-run admin password

# === ML Sidecar ===
REFRAME_ML_URL=http://reframe-ml:8100
REFRAME_ML_ENABLED=true
REFRAME_ML_FACE_RECOGNITION=true
REFRAME_ML_CLIP_SEARCH=true
REFRAME_ML_OCR=true

# === Redis ===
REFRAME_REDIS_URL=redis://reframe-redis:6379

# === Media Processing ===
REFRAME_THUMBNAIL_QUALITY=80              # WebP quality 1-100
REFRAME_VIDEO_TRANSCODE_ENABLED=true
REFRAME_VIDEO_HW_ACCEL=auto              # auto | vaapi | nvenc | none
REFRAME_MAX_UPLOAD_SIZE_MB=500
REFRAME_FFMPEG_THREADS=0                  # 0 = auto

# === Features ===
REFRAME_TRASH_AUTO_DELETE_DAYS=30
REFRAME_DEFAULT_STORAGE_QUOTA_GB=0        # 0 = unlimited
REFRAME_REGISTRATION_ENABLED=false        # Invite-only by default
REFRAME_MAP_TILE_PROVIDER=osm             # osm | mapbox
REFRAME_MAPBOX_TOKEN=                     # Required if using Mapbox
REFRAME_GEOCODING_PROVIDER=nominatim      # nominatim | mapbox

# === Timezone ===
TZ=America/Detroit
```

---

## 16. Key Technical Decisions & Rationale

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Backend language | Go | Concurrency, low memory, single binary, fast file I/O |
| ML language | Python (sidecar) | Best ML ecosystem, decoupled from backend |
| Database | SQLite (WAL) | Zero-config, single file, perfect for household scale |
| Mobile | React Native | True background upload, cross-platform, large ecosystem |
| Thumbnails | WebP via libvips | 30% smaller than JPEG, libvips 8x faster than ImageMagick |
| Video | HLS via FFmpeg | Universal adaptive streaming, hardware acceleration |
| Face recognition | InsightFace + ArcFace | State-of-the-art accuracy, runs on CPU, ONNX optimized |
| Visual search | CLIP ViT-B/32 | Natural language → image search, no manual tagging |
| Storage abstraction | Interface pattern | Supports NAS → S3 migration without data model changes |
| Auth | JWT + invite codes | Simple household onboarding, no email server required |
| Deployment | Docker Compose | One-command deploy, works on NAS/Pi/VPS/desktop |
| QR sharing | SVG generation | No external dependency, works offline |
| Map tiles | OpenStreetMap | Free, no API key, self-hostable |
| License | MIT | Maximum adoption for open source |

---

## Appendix A: Supported File Formats

### Photos
| Format | Extension | MIME Type | Notes |
|--------|-----------|-----------|-------|
| JPEG | .jpg, .jpeg | image/jpeg | Primary format |
| PNG | .png | image/png | Screenshots, graphics |
| HEIC/HEIF | .heic, .heif | image/heic | iPhone default |
| WebP | .webp | image/webp | Modern web format |
| GIF | .gif | image/gif | Animated supported |
| BMP | .bmp | image/bmp | Legacy support |
| TIFF | .tif, .tiff | image/tiff | High-quality scans |

### RAW Formats
| Format | Extension | Camera |
|--------|-----------|--------|
| CR2 | .cr2 | Canon |
| CR3 | .cr3 | Canon (newer) |
| NEF | .nef | Nikon |
| ARW | .arw | Sony |
| DNG | .dng | Adobe (universal) |
| RAF | .raf | Fujifilm |
| ORF | .orf | Olympus |
| RW2 | .rw2 | Panasonic |

### Video
| Format | Extension | MIME Type |
|--------|-----------|-----------|
| MP4 | .mp4 | video/mp4 |
| MOV | .mov | video/quicktime |
| AVI | .avi | video/x-msvideo |
| MKV | .mkv | video/x-matroska |
| WebM | .webm | video/webm |

### Documents
| Format | Extension | MIME Type |
|--------|-----------|-----------|
| PDF | .pdf | application/pdf |

---

## Appendix B: ML Model Specifications

| Model | Task | Input | Output | Size | Latency (CPU) |
|-------|------|-------|--------|------|---------------|
| SCRFD-10GF | Face detection | Image | Bounding boxes + landmarks | ~30 MB | ~50ms |
| ArcFace-R100 | Face embedding | Aligned face 112x112 | 512-dim float32 vector | ~250 MB | ~20ms/face |
| CLIP ViT-B/32 | Image embedding | Image 224x224 | 512-dim float32 vector | ~350 MB | ~100ms |
| CLIP ViT-B/32 | Text embedding | Text string | 512-dim float32 vector | (shared) | ~10ms |
| Tesseract 5 | OCR | Image | Text string | ~15 MB | ~200ms/page |

**Total ML model footprint:** ~650 MB disk, ~2 GB RAM when loaded.

**Vector search implementation:** For household scale (< 500K photos), brute-force cosine similarity on SQLite BLOB vectors is sufficient (~50ms for 100K vectors). If needed, sqlite-vss extension can add approximate nearest neighbor search.

---

*End of Design Document*
