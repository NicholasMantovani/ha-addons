# Changelog

All notable changes to this add-on are documented here. Entries for upstream
version bumps are added automatically by the `sync-upstream` workflow.

<!-- next-entry -->

## 1.7.0.2

- The direct port 8084 serves Shelfmark at the root again, like a plain
  install. In 1.7.0.1 it showed a blank page at `/` and only worked under the
  Ingress path, which broke reverse proxies and Tailscale Serve on a domain
  root.
- Shelfmark no longer runs under the Ingress path: nginx adds it for Ingress
  requests only (from the `X-Ingress-Path` header), so OIDC callback URLs on
  the direct port no longer contain it.
- The add-on no longer needs Supervisor API access.

## 1.7.0.1

- Home Assistant Ingress: open Shelfmark from the Home Assistant sidebar,
  also remotely (Nabu Casa or your own HTTPS access to Home Assistant).
- The app now listens on 127.0.0.1 only; nginx serves both Ingress (8099)
  and the direct port 8084, adding the Ingress URL prefix automatically.

## 1.7.0

- Initial release of the add-on, based on Shelfmark
  [v1.7.0](https://github.com/calibrain/shelfmark/releases/tag/v1.7.0)
  (standard image).
- Downloads go to `/media/calibre/ingest` by default, so Calibre-Web Automated
  imports them automatically.
- Optional Library Check against the Calibre `metadata.db`.
- Network mode `direct` or `tor`.
- Configurable PUID, PGID, timezone, log level and extra environment variables.
