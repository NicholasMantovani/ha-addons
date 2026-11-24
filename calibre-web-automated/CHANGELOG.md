# Changelog

All notable changes to this add-on are documented here. Entries for upstream
version bumps are added automatically by the `sync-upstream` workflow.

<!-- next-entry -->

## 4.0.8

- Initial release of the add-on, based on Calibre-Web Automated
  [v4.0.8](https://github.com/crocodilestick/Calibre-Web-Automated/releases/tag/v4.0.8).
- Configurable library and ingest paths in `/share` or `/media` (bind-mounted,
  inotify-friendly).
- Application config persisted in the add-on `/data` directory.
- Configurable PUID, PGID and timezone.
- `env_vars` option to pass extra environment variables (e.g.
  `NETWORK_SHARE_MODE=true` for libraries on a NAS).
