# Shelfmark

[Shelfmark][shelfmark] is a self-hosted web interface to search and download
books and audiobooks across multiple sources, with metadata from providers
such as Hardcover, Open Library and Google Books. This add-on uses the
**standard** upstream image, which includes a built-in browser to get past
Cloudflare-protected sources.

> **Requirements:** the standard image needs **at least 2 GB of RAM** free for
> the add-on. On a Raspberry Pi with 4 GB or less, keep an eye on memory use.

## First start

1. Review the **Configuration** tab (see below), then start the add-on.
2. Click **Open Web UI**, or browse to `http://<home-assistant-ip>:8084`.
3. The onboarding wizard guides you through the first settings.
4. **Enable authentication.** By default Shelfmark has **no login**
   (`AUTH_METHOD=none`): anyone on your network can use it. Go to
   **Settings → Authentication** and choose built-in login (or OIDC / proxy
   auth), then create your admin user.

## Configuration

```yaml
download_path: /media/calibre/ingest
puid: 0
pgid: 0
timezone: Europe/Rome
network_mode: direct
calibre_library_check: true
calibre_library_path: /media/calibre/library
log_level: info
env_vars: []
```

### `download_path`

Where finished downloads are saved. Must be inside `/share` or `/media`.
The default is the ingest folder of the **Calibre-Web Automated** add-on:
every book downloaded by Shelfmark is imported into your library
automatically. If your Calibre-Web Automated `ingest_path` is different (for
example `/share/calibre/ingest`), use the same value here.

Per-user folders are possible with the `{User}` placeholder, e.g.
`/media/books/{User}`.

### `puid` / `pgid`

User and group IDs used to write the downloaded files. Keep the default `0`
(root) when downloading into the Calibre-Web Automated ingest folder: both
add-ons then use the same owner and there are no permission conflicts.

### `timezone`

IANA timezone name, e.g. `Europe/Rome`. Invalid values fall back to `Etc/UTC`.

### `network_mode`

- `direct` (default): normal network access.
- `tor`: route **all** Shelfmark traffic through Tor (iptables, uses the
  `NET_ADMIN` / `NET_RAW` privileges of the add-on). Slower, but hides your IP
  from the sources.

WireGuard mode is **not available** in the add-on: it needs container sysctls
that Home Assistant does not allow add-ons to set. Use a VPN at router level,
or the HTTP/SOCKS5 proxy setting in Shelfmark, instead.

### `calibre_library_check` / `calibre_library_path`

When enabled, Shelfmark reads (read-only) the `metadata.db` of your Calibre
library and marks search results you already own, so you do not download a
second copy. `calibre_library_path` must be the folder that contains
`metadata.db`, i.e. the `library_path` of the Calibre-Web Automated add-on.
If the file does not exist yet (Calibre-Web Automated never started), the
feature stays off and a warning is logged.

### `calibre_web_url` (optional)

Adds a button in the Shelfmark header that opens your library, e.g.
`http://192.168.1.10:8083`. Click **Show unused optional configuration
options** to see this field.

### `log_level`

`debug`, `info`, `warning` or `error`.

### `env_vars`

Extra environment variables for anything the add-on does not expose directly.
Example:

```yaml
env_vars:
  - name: SEARCH_MODE
    value: universal
  - name: BOOK_LANGUAGE
    value: it,en
  - name: SESSION_COOKIE_SECURE
    value: "true"
```

See the upstream [environment variables reference][envvars]. Most settings
can also be changed from Shelfmark's **Settings** page, where environment
variables act as defaults. Variables managed by the add-on options (`PUID`,
`PGID`, `TZ`, `CONFIG_DIR`, `INGEST_DIR`, `USING_TOR`, `USING_WIREGUARD`) are
ignored here.

## Sources, indexers and download clients

All sources are configured in **Settings** inside the web UI: direct download
mirrors, Prowlarr / Jackett indexers, torrent and usenet clients, IRC,
Soulseek (slskd) and metadata providers (a free Hardcover API key is
recommended for the "Universal" search mode).

When a torrent/usenet client runs in another add-on (for example qBittorrent),
its download folder must be visible to Shelfmark **at the same path**. With
both add-ons saving under `/share` or `/media`, the paths match
automatically.

> You are responsible for the sources you configure and for complying with
> copyright law in your country.

## Data and backups

| What | Where | In HA backups |
| ---- | ----- | ------------- |
| Settings, users, database, artwork cache | `/addon_configs/xxxxxxxx_shelfmark` (Samba: `addon_configs`) | Yes |
| Downloaded books | `download_path` | Only if you include `share` / `media` |

## Troubleshooting

- **Add-on stops right after starting:** check the **Log** tab for
  `[ha-run] ERROR:` lines (invalid paths) or upstream errors.
- **Cloudflare-protected sources fail / out of memory:** the built-in
  browser needs RAM. Close other heavy add-ons or use sources that do not
  require the bypass.
- **Downloads are not imported into Calibre-Web Automated:** make sure
  `download_path` is exactly the Calibre-Web Automated `ingest_path`.

[shelfmark]: https://github.com/calibrain/shelfmark
[envvars]: https://github.com/calibrain/shelfmark/blob/main/docs/environment-variables.md
