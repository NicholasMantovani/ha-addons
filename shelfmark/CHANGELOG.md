# Changelog

All notable changes to this add-on are documented here. Entries for upstream
version bumps are added automatically by the `sync-upstream` workflow.

<!-- next-entry -->

## 1.7.0

- Initial release of the add-on, based on Shelfmark
  [v1.7.0](https://github.com/calibrain/shelfmark/releases/tag/v1.7.0)
  (standard image).
- Downloads go to `/media/calibre/ingest` by default, so Calibre-Web Automated
  imports them automatically.
- Optional Library Check against the Calibre `metadata.db`.
- Network mode `direct` or `tor`.
- Configurable PUID, PGID, timezone, log level and extra environment variables.
