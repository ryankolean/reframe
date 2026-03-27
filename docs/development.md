# Reframe Development Guide

## Prerequisites

- Go 1.22+
- Python 3.11+
- Node.js 20+ (with npm)
- Docker + Docker Compose
- FFmpeg 6+
- libvips 8.14+
- LibRaw
- Redis 7+

## Project Structure

```
reframe/
├── server/          Go backend (API, media processing, storage)
├── ml/              Python ML sidecar (faces, CLIP, OCR)
├── web/             React web client (Vite + TypeScript)
├── mobile/          React Native mobile app (Expo)
├── plugins/         Plugin templates and official plugins
├── docs/            Documentation
└── docker-compose.yml
```

## Running Locally

### Option 1: Docker Compose (Recommended)

```bash
cp .env.example .env
# Edit .env with your settings
docker compose up -d
```

### Option 2: Individual Services

**Terminal 1 — Go Backend:**
```bash
cd server
# Install system deps: libvips-dev, libraw-dev, ffmpeg
go mod download
go run cmd/server/main.go
```

**Terminal 2 — Python ML Sidecar:**
```bash
cd ml
python -m venv venv
source venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --reload --port 8100
```

**Terminal 3 — Web Client:**
```bash
cd web
npm install
npm run dev
```

**Terminal 4 — Redis:**
```bash
docker run -d --name reframe-redis -p 6379:6379 redis:7-alpine
```

**Terminal 5 — Mobile (optional):**
```bash
cd mobile
npm install
npx expo start
```

## Code Style

| Language | Formatter | Linter | Type Checker |
|----------|-----------|--------|-------------|
| Go | gofmt | golangci-lint | N/A (compiled) |
| Python | Black | Ruff | mypy (strict) |
| TypeScript | Prettier | ESLint | tsc --noEmit |

## Testing

```bash
# Go
cd server && go test -race ./...

# Python
cd ml && pytest tests/ -v

# Web
cd web && npm test

# Mobile
cd mobile && npm test
```

## Database Migrations

Migrations are SQL files in `server/migrations/`. They run automatically on startup in order.

To create a new migration:
```bash
touch server/migrations/002_your_change.sql
```

## Adding a New API Endpoint

1. Define the handler in `server/internal/api/handlers/`
2. Register the route in `server/internal/api/router.go`
3. Add DTOs in `server/internal/api/dto/`
4. Add service logic in `server/internal/services/`
5. Write tests
6. Update `docs/api.md`

## Adding a New ML Model

1. Add model loading in `ml/app/models/`
2. Add API endpoint in `ml/app/api/`
3. Register in `ml/app/main.py`
4. Update the health check to report model status
5. Add Docker model download step if needed
