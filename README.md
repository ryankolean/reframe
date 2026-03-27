# Reframe

**Your photos. Your server. Your rules.**

Reframe is an open-source, self-hosted alternative to Google Photos. It provides full photo and video backup, AI-powered search, face recognition, timeline browsing, map view, memories, and sharing — all running on your own hardware with no cloud dependency required.

## Features

- **Background Sync** — Silent photo and video backup from iOS and Android
- **Timeline View** — Browse your entire library chronologically with smooth virtualized scrolling
- **AI-Powered Search** — Search "beach sunset" and find matching photos using CLIP embeddings
- **Face Recognition** — Automatic face detection, clustering, and person tagging using InsightFace/ArcFace
- **Map View** — See where your photos were taken on an interactive map
- **Memories** — "On this day" memories surfaced daily
- **Albums & Sharing** — Create albums, share via link or QR code, collaborate with family
- **Partner Sharing** — Auto-share photos of specific people with your partner
- **Video Support** — Full video upload, HLS transcoding, and adaptive streaming
- **RAW Support** — CR2, NEF, ARW, DNG, and more
- **EXIF Viewer** — Full camera, lens, and shooting data for every photo
- **Favorites, Archive, Locked Folder** — Organize and protect your photos
- **Duplicate Detection** — Find and resolve duplicate photos
- **Storage Dashboard** — Monitor usage per user with quota management
- **Plugin System** — Extensible architecture for community integrations
- **Document OCR** — Search text within screenshots and scanned documents

## Architecture

| Component | Technology |
|-----------|-----------|
| Backend | Go (Gin, SQLite, libvips, FFmpeg) |
| ML Sidecar | Python (FastAPI, InsightFace, CLIP, Tesseract) |
| Mobile | React Native (iOS + Android) |
| Web | React + TypeScript + Vite |
| Database | SQLite (WAL mode) |
| Deployment | Docker Compose |

## Quick Start

```bash
# Clone the repo
git clone https://github.com/ryankolean/reframe.git
cd reframe

# Copy environment template
cp .env.example .env

# Edit .env with your settings (JWT_SECRET, ADMIN_PASSWORD)
nano .env

# Start Reframe
docker compose up -d
```

Open `http://localhost:2283` and complete the setup wizard.

## Hardware Requirements

| Tier | CPU | RAM | Storage | Users |
|------|-----|-----|---------|-------|
| Minimum | 2 cores | 4 GB | 50 GB | 1–2 |
| Recommended | 4 cores | 8 GB | 500 GB | 2–5 |
| Power | 6+ cores | 16 GB | 2+ TB | 5–10 |

GPU (NVIDIA) is optional but provides ~10x faster ML processing.

## Mobile Apps

React Native apps for iOS and Android with true background sync — your photos upload silently even when the app is closed.

## Documentation

- [Design Document](docs/DESIGN.md) — Complete architecture and specification
- [API Reference](docs/api.md) — REST API documentation
- [Deployment Guide](docs/deployment.md) — Detailed deployment instructions
- [Plugin Development](docs/plugins.md) — Build extensions for Reframe
- [Contributing](CONTRIBUTING.md) — How to contribute

## Roadmap

- [x] Design document and architecture
- [ ] **Phase 1** — Core upload/browse/view (Weeks 1–4)
- [ ] **Phase 2** — Background sync + video (Weeks 5–8)
- [ ] **Phase 3** — AI features: faces, search, OCR (Weeks 9–12)
- [ ] **Phase 4** — Albums, sharing, partner sharing (Weeks 13–16)
- [ ] **Phase 5** — Map, memories, duplicates (Weeks 17–20)
- [ ] **Phase 6** — Plugins, polish, documentation (Weeks 21–24)

## Comparison

| Feature | Reframe | Google Photos | Immich | PhotoPrism |
|---------|---------|--------------|--------|------------|
| Self-hosted | Yes | No | Yes | Yes |
| Background sync (iOS + Android) | Yes | N/A | Yes | No |
| CLIP visual search | Yes | Yes (cloud) | Yes | No |
| Face recognition | Yes | Yes (cloud) | Yes | Yes |
| Video transcoding (HLS) | Yes | Yes (cloud) | Yes | No |
| RAW support | Yes | Partial | Yes | Yes |
| Plugin/extension API | Yes | No | No | No |
| Partner sharing | Yes | Yes | Yes | No |
| QR code sharing | Yes | No | No | No |
| Document OCR | Yes | Yes (cloud) | No | No |
| License | MIT | Proprietary | AGPL | AGPL |
| Language | Go + Python | N/A | TypeScript | Go |

## Tech Stack Details

### Why Go + Python?

**Go** handles the heavy lifting: concurrent uploads, thumbnail generation via libvips, video transcoding orchestration via FFmpeg, and serving thousands of requests with minimal memory. Perfect for self-hosted environments running on a NAS or Raspberry Pi.

**Python** runs as a separate ML sidecar service for face recognition (InsightFace/ArcFace), visual search (CLIP), and OCR (Tesseract). It can be disabled entirely on low-power hardware — the app degrades gracefully to metadata-only search.

### Why SQLite?

For a household photo manager (2–10 users), SQLite in WAL mode provides excellent read concurrency, zero configuration, single-file backup, and no additional server process. It comfortably handles 500K+ photos.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) — Use it however you want.

## Acknowledgments

Inspired by the excellent work of [Immich](https://github.com/immich-app/immich), [PhotoPrism](https://github.com/photoprism/photoprism), and [LibrePhotos](https://github.com/LibrePhotos/librephotos). Reframe aims to bring its own vision to the self-hosted photo management space.
