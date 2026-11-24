# Nicholas Mantovani's Home Assistant Add-ons

[![Lint](https://github.com/NicholasMantovani/ha-addons/actions/workflows/lint.yml/badge.svg)](https://github.com/NicholasMantovani/ha-addons/actions/workflows/lint.yml)
[![Sync upstream](https://github.com/NicholasMantovani/ha-addons/actions/workflows/sync-upstream.yml/badge.svg)](https://github.com/NicholasMantovani/ha-addons/actions/workflows/sync-upstream.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Home Assistant add-ons for a self-hosted e-book setup. Each add-on is a thin,
configurable layer on top of the official upstream image.

## Installation

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FNicholasMantovani%2Fha-addons)

1. Click the button above, or in Home Assistant go to
   **Settings → Add-ons → Add-on Store → ⋮ → Repositories** and add
   `https://github.com/NicholasMantovani/ha-addons`.
2. Install the add-ons you want from the store.
3. Review each add-on's **Configuration** tab, then start it.

Add-ons are built locally on top of the upstream images, so the first
installation downloads the full upstream image (about 1 GB each).

Both add-ons support **Home Assistant Ingress**: they open inside Home
Assistant (and from its sidebar), so they are reachable from outside your
home wherever Home Assistant is (Home Assistant Cloud or your own HTTPS
access), with no extra ports to open. Direct LAN ports remain available
(needed by OPDS readers and Kobo Sync).

## Add-ons

| | Add-on | Version | Description |
| --- | --- | --- | --- |
| <img src="calibre-web-automated/icon.png" width="48"> | [Calibre-Web Automated](calibre-web-automated/) | [![Version](https://img.shields.io/github/v/release/NicholasMantovani/ha-addons?filter=calibre-web-automated-*&label=)](https://github.com/NicholasMantovani/ha-addons/releases?q=calibre-web-automated) | E-book library with automatic ingest, conversion, OPDS and Kobo Sync |
| <img src="shelfmark/icon.png" width="48"> | [Shelfmark](shelfmark/) | [![Version](https://img.shields.io/github/v/release/NicholasMantovani/ha-addons?filter=shelfmark-*&label=)](https://github.com/NicholasMantovani/ha-addons/releases?q=shelfmark) | Search and download books and audiobooks, imported automatically into Calibre-Web Automated |

### Using them together

```text
Shelfmark ──downloads──▶ /media/calibre/ingest ──CWA imports──▶ /media/calibre/library
    ▲                                                                   │
    └──────────── "Library Check" reads metadata.db (read-only) ◀───────┘
```

1. In **Calibre-Web Automated**, set `library_path: /media/calibre/library`
   and `ingest_path: /media/calibre/ingest`.
2. In **Shelfmark**, keep the defaults (`download_path: /media/calibre/ingest`,
   `calibre_library_path: /media/calibre/library`).

If you prefer `/share`, use the same `/share/...` paths in both add-ons.

## Updates and releases

Updates are deliberately simple and under your control:

- **[`.github/addons.yaml`](.github/addons.yaml)** lists, for each add-on,
  the upstream repository and image to follow and whether to update it
  automatically (`auto_update: true|false`).
- **[`sync-upstream`](.github/workflows/sync-upstream.yml)** runs every Monday
  at 06:00 UTC. For each add-on with `auto_update: true`, when a new upstream
  release exists **and** its image is published for every architecture, it:
  1. updates `version` in `config.yaml` (with the `v` prefix removed);
  2. updates the image tag in `build.yaml` and `Dockerfile`;
  3. adds an entry to `CHANGELOG.md` linking the upstream release notes;
  4. commits and pushes to `main`.

  You can also run it manually from the **Actions** tab, for a single add-on
  (even one with `auto_update: false`) and/or as a **dry run** that only shows
  what would change.
- **[`release`](.github/workflows/release.yml)** publishes a GitHub release
  `<addon>-v<version>` (e.g. `shelfmark-v1.7.0`) for every add-on version that
  has not been released yet, using its `CHANGELOG.md` section as notes. It
  runs on every push to `main` and after each sync.

### Manual changes

To ship an add-on-only change (no upstream update), add a fourth number to
the version, e.g. `4.0.8` → `4.0.8.1`. Add a `## 4.0.8.1` section to the
add-on's `CHANGELOG.md` and push: the release is created and Home Assistant
offers the update. Don't use a `-1` suffix: semver treats `4.0.8-1` as a
pre-release, lower than `4.0.8`.

> Commits pushed by the workflow with the default `GITHUB_TOKEN` do not
> trigger `lint.yml`. If `main` is branch-protected, allow
> `github-actions[bot]` to push or use a PAT.

### Adding a new add-on

1. Create a folder with `config.yaml`, `build.yaml`, `Dockerfile`, `DOCS.md`,
   `README.md`, `icon.png`, `logo.png` and a `CHANGELOG.md` containing the
   `<!-- next-entry -->` marker.
2. Add an entry to `.github/addons.yaml`.
3. Push: lint, release and weekly sync pick it up automatically.

## License

The add-on packaging in this repository is released under the
[MIT License](LICENSE). Each upstream application keeps its own license:
Calibre-Web Automated (GPL-3.0), Shelfmark (MIT).
