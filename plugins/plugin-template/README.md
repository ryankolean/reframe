# Reframe Plugin Template

Use this template to build custom plugins for Reframe.

## Plugin Types

| Type | Description |
|------|-------------|
| `editor` | Send an asset to an external tool, receive edited version back |
| `export` | Export assets to external services |
| `import` | Import from external sources |
| `processing` | Run custom processing on assets |

## Getting Started

1. Copy this directory and rename it
2. Edit `manifest.json` with your plugin details
3. Implement the plugin according to the [Plugin API docs](../../docs/plugins.md)
4. Test with a local Reframe instance
5. Submit a PR to include it in the official plugin registry

## Manifest Fields

- `id` — Unique identifier (lowercase, hyphens only)
- `name` — Display name
- `version` — Semver version
- `type` — Plugin type (see above)
- `entry_url` — URL that Reframe will open/call
- `accepts` — MIME types this plugin can process
- `returns` — MIME types this plugin produces
- `icon` — SVG icon file
- `settings` — User-configurable settings schema

## Lifecycle

1. User selects asset(s) and chooses your plugin
2. Reframe generates a signed temporary URL for the asset(s)
3. Your plugin receives the URL(s) and processes the asset
4. Your plugin POSTs the result back to the Reframe callback URL
5. Reframe creates a new asset version (original is preserved)
