# Reframe API Reference

> Full API specification is defined in [DESIGN.md](DESIGN.md), Section 6.

API documentation will be auto-generated from OpenAPI/Swagger annotations once the Go server is implemented.

## Base URL

```
https://your-server:2283/api/v1/
```

## Authentication

All endpoints (except `/auth/login`, `/auth/register`, and `/share/:token`) require a Bearer JWT token in the Authorization header:

```
Authorization: Bearer <access_token>
```

## Quick Reference

| Group | Endpoints | Description |
|-------|-----------|-------------|
| Auth | `/auth/*` | Register, login, refresh, logout |
| Assets | `/assets/*` | Upload, browse, view, organize |
| Search | `/search` | CLIP visual search + metadata search |
| People | `/people/*`, `/faces/*` | Face recognition management |
| Albums | `/albums/*` | Album CRUD + collaboration |
| Sharing | `/share/*` | Link + QR code sharing |
| Partner | `/partner-sharing/*` | Auto-share by face |
| Memories | `/memories/*` | "On this day" features |
| Duplicates | `/duplicates/*` | Duplicate detection + resolution |
| Admin | `/admin/*` | Server management (admin only) |
| Sync | `/sync/*` | Mobile sync endpoints |
| Plugins | `/plugins/*` | Extension system |
| WebSocket | `/ws` | Real-time events |
