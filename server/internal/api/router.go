package api

// TODO: Phase 1 — implement Gin router with all API endpoints
//
// Router structure:
//
// /api/v1/
//   /auth/register        POST
//   /auth/login           POST
//   /auth/refresh         POST
//   /auth/logout          POST
//   /auth/me              GET, PUT
//
//   /assets               GET
//   /assets/upload        POST
//   /assets/check-duplicate POST
//   /assets/:id           GET, PUT, DELETE
//   /assets/:id/original  GET
//   /assets/:id/thumbnail/:size GET
//   /assets/:id/video     GET
//   /assets/:id/favorite  PUT
//   /assets/:id/archive   PUT
//   /assets/:id/lock      PUT
//   /assets/:id/restore   POST
//   /assets/bulk          POST
//
//   /search               POST
//
//   /people               GET
//   /people/:id           GET, PUT
//   /people/:id/merge     POST
//   /people/:id/assets    GET
//   /faces/:id/assign     POST
//   /faces/unassigned     GET
//
//   /albums               GET, POST
//   /albums/:id           GET, PUT, DELETE
//   /albums/:id/assets    POST, DELETE
//   /albums/:id/share     POST, DELETE
//   /albums/:id/activity  GET
//
//   /share                POST
//   /share/:token         GET (public)
//   /share/:token/qr      GET (public)
//
//   /partner-sharing      GET, POST
//   /partner-sharing/:id  PUT, DELETE
//
//   /memories             GET
//   /memories/:id         GET
//   /memories/:id/dismiss PUT
//
//   /duplicates           GET
//   /duplicates/:id/resolve PUT
//   /duplicates/:id/dismiss PUT
//
//   /admin/users          GET
//   /admin/users/:id      PUT, DELETE
//   /admin/invite-codes   GET, POST
//   /admin/server/stats   GET
//   /admin/server/settings GET, PUT
//   /admin/server/health  GET
//   /admin/server/jobs    GET
//
//   /sync/status          GET
//   /sync/changes         POST
//
//   /plugins              GET
//   /plugins/:id/execute  POST
//
//   /ws                   WebSocket
