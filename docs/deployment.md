# Reframe Deployment Guide

## Quick Start (Docker Compose)

```bash
git clone https://github.com/ryankolean/reframe.git
cd reframe
cp .env.example .env
# Edit .env — set JWT_SECRET and ADMIN_PASSWORD at minimum
docker compose up -d
```

Open `http://localhost:2283` and complete the setup wizard.

## Production Deployment with HTTPS

1. Point your domain (e.g., `photos.yourdomain.com`) to your server's IP
2. Edit `Caddyfile` — replace `photos.yourdomain.com` with your domain
3. Uncomment the Caddy service in `docker-compose.yml` or run Caddy separately
4. Caddy will automatically provision a Let's Encrypt HTTPS certificate

## S3-Compatible Storage

To use S3, MinIO, or Backblaze B2 instead of local filesystem:

```bash
REFRAME_STORAGE_BACKEND=s3
REFRAME_S3_ENDPOINT=http://minio:9000    # or https://s3.amazonaws.com
REFRAME_S3_BUCKET=reframe
REFRAME_S3_ACCESS_KEY=your-key
REFRAME_S3_SECRET_KEY=your-secret
REFRAME_S3_REGION=us-east-1
```

## GPU Acceleration (NVIDIA)

For faster ML processing, add the NVIDIA runtime to the ML sidecar:

```yaml
reframe-ml:
  # ... existing config ...
  environment:
    - REFRAME_ML_DEVICE=cuda
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu]
```

Requires [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/).

## Disabling ML Features

For low-power hardware (Raspberry Pi, etc.), disable the ML sidecar:

```bash
REFRAME_ML_ENABLED=false
```

Or start without it: `docker compose up -d reframe reframe-redis`

## Backup

SQLite database: `/data/database/reframe.db`
Media files: `/data/originals/`

```bash
# Stop Reframe (for consistent backup)
docker compose stop reframe

# Backup database
cp /path/to/reframe-data/database/reframe.db /backup/reframe-$(date +%Y%m%d).db

# Backup media (rsync for incremental)
rsync -av /path/to/reframe-data/originals/ /backup/originals/

# Restart
docker compose start reframe
```

## Hardware Sizing

| Tier | CPU | RAM | Storage | Users |
|------|-----|-----|---------|-------|
| Minimum | 2 cores | 4 GB | 50 GB | 1–2 |
| Recommended | 4 cores | 8 GB | 500 GB | 2–5 |
| Power | 6+ cores | 16 GB | 2+ TB | 5–10 |

## Supported Platforms

- Linux x86_64 / ARM64
- macOS (Docker Desktop)
- Windows (Docker Desktop / WSL2)
- Synology / QNAP NAS (Docker)
- Raspberry Pi 4/5 (ARM64)
