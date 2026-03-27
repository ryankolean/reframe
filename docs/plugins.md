# Reframe Plugin Development Guide

Reframe supports a plugin/extension system that allows community developers to build integrations for photo editing, export, import, and custom processing.

## Plugin Types

| Type | Flow | Example |
|------|------|---------|
| `editor` | Asset → Plugin → Edited asset back | Photopea, Remove.bg, AI Upscaler |
| `export` | Asset → Plugin → External service | Flickr, SmugMug, social media |
| `import` | External source → Plugin → New assets | Google Takeout, iCloud import |
| `processing` | Asset → Plugin → Metadata/tags | Watermark, custom ML model |

## Creating a Plugin

1. Copy `plugins/plugin-template/` to a new directory
2. Edit `manifest.json` with your plugin details
3. Implement the plugin logic
4. Test with a local Reframe instance

## Manifest Schema

See `plugins/plugin-template/manifest.json` for a complete example.

## Editor Plugin Flow

1. User selects asset(s) and clicks "Edit with [Your Plugin]"
2. Reframe generates temporary signed URLs for the selected assets
3. Reframe opens your plugin's `entry_url` with parameters:
   - `assets[]` — Array of signed asset URLs
   - `callback` — URL to POST the edited result back to
   - `token` — One-time authentication token
4. Your plugin processes the asset(s)
5. Your plugin POSTs the result to the callback URL
6. Reframe creates a new asset version (original is always preserved)

## API Endpoints

```
GET  /api/v1/plugins              List installed plugins
POST /api/v1/plugins/:id/execute  Start plugin execution on asset(s)
POST /api/v1/plugins/callback     Receive results from plugin (authenticated via one-time token)
```

## Contributing Plugins

Submit plugins as PRs to the `plugins/` directory. Each plugin must include a `manifest.json` and `README.md`.
