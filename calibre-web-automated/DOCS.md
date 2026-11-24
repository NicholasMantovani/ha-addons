# Calibre-Web Automated

[Calibre-Web Automated][cwa] (CWA) is a web app for browsing, reading and
managing a Calibre e-book library. It adds automatic ingest, automatic
conversion, metadata enforcement, OPDS and Kobo Sync, all without a desktop
Calibre installation.

## First start

1. Install the add-on and start it. The first start takes a while because CWA
   prepares the Calibre binaries and creates an empty library if needed.
2. Click **Open Web UI**, or browse to `http://<home-assistant-ip>:8083`.
3. Log in with the default credentials:

   | Username | Password   |
   | -------- | ---------- |
   | `admin`  | `admin123` |

4. **Change the password right away** from the profile page (top right). The
   web UI is exposed on your local network.

## Configuration

```yaml
library_path: /share/calibre/library
ingest_path: /share/calibre/ingest
puid: 0
pgid: 0
timezone: Europe/Rome
env_vars: []
```

### `library_path`

Folder that contains (or will contain) the Calibre library, i.e. the folder
with `metadata.db` in it. If the folder is empty, CWA creates a new library.
To use an existing library made with Calibre desktop, copy the whole library
folder (with `metadata.db`) here.

### `ingest_path`

The drop folder for new books (see [Automatic ingest](#automatic-ingest)).

### `puid` / `pgid`

The user and group IDs that own the library files. The default `0` (root)
lets the Samba add-on and the Media Browser read and write the books without
permission issues. If you change these values, the add-on updates file
ownership on the next start (once, recursively).

### `timezone`

An IANA timezone name such as `Europe/Rome` or `America/New_York`. Invalid
values fall back to `Etc/UTC` and a warning is logged.

### `env_vars`

Extra environment variables passed to Calibre-Web Automated, for options the
add-on does not expose directly. Example:

```yaml
env_vars:
  - name: NETWORK_SHARE_MODE
    value: "true"
  - name: TRUSTED_PROXY_COUNT
    value: "2"
```

- `NETWORK_SHARE_MODE=true`: use polling instead of inotify. Enable it when the
  library or ingest folder lives on a NAS (SMB/NFS).
- `TRUSTED_PROXY_COUNT`: number of reverse proxies in front of CWA.

See the [upstream documentation][cwa] for all variables. `PUID`, `PGID` and
`TZ` are ignored here: use the dedicated options.

## Choosing between `/share` and `/media`

Both locations are mapped read/write into the add-on, and both paths must be
inside one of them:

| Location | Reachable through                            | Example                          |
| -------- | -------------------------------------------- | -------------------------------- |
| `/share` | Samba / SSH add-ons (`share` folder)         | `/share/calibre/library`         |
| `/media` | Samba (`media` folder), **Media Browser**, external/network storage added under *Settings → System → Storage* | `/media/books/library` |

To move the library:

1. Stop the add-on.
2. Move or copy the library folder to the new location (for example with the
   Samba add-on), keeping `metadata.db` together with the book folders.
3. Update `library_path` (and `ingest_path` if needed) in the
   **Configuration** tab.
4. Start the add-on.

Missing folders are created automatically. Paths outside `/share` or `/media`
are rejected and the add-on will refuse to start, as will an `ingest_path`
that is the same as, or nested inside, `library_path` (or the other way
round).

> **Network storage:** a NAS share added in Home Assistant under
> *Settings → System → Storage* with usage **Media** or **Share** appears
> under `/media/<name>` or `/share/<name>` and works as well. Keep in mind that
> SQLite (`metadata.db`) over SMB/NFS can be slow, and NAS shares usually do
> not deliver inotify events: add `NETWORK_SHARE_MODE=true` to
> [`env_vars`](#env_vars) in that case.

## Automatic ingest

Every file you put in the ingest folder (`ingest_path`) is picked up by CWA:

1. The new file is detected immediately (inotify).
2. If needed, it is converted to your preferred format (EPUB by default,
   configurable in the **CWA Settings** page).
3. It is imported into the library together with its metadata and cover.
4. **The original file is deleted from the ingest folder.**

A convenient workflow is to map the ingest folder through Samba
(`\\homeassistant\share\calibre\ingest`) and drop books there from your PC.

Notes:

- Do not edit files in place inside the ingest folder. Copy finished files
  into it.
- Files that fail to import are moved to a `failed` area and reported in the
  CWA logs and stats pages.
- Format conversion, metadata fetching, the auto-backup of replaced files and
  other behaviours are configured in the web UI under **Admin → CWA Settings**.

## OPDS (e-reader apps)

OPDS lets reader apps (KOReader, Moon+ Reader, Librera, Marvin, Panels...)
browse and download your library.

- **Feed URL:** `http://<home-assistant-ip>:8083/opds`
- **Authentication:** your Calibre-Web username and password (HTTP Basic).

If the feed is not available, check **Admin → Edit Basic Configuration →
Feature Configuration**. To expose the catalogue outside your home network,
put it behind HTTPS (a reverse proxy such as the NGINX Proxy Manager add-on),
because Basic authentication sends credentials with every request.

## Kobo Sync

Kobo Sync makes the library appear on a Kobo e-reader as if it were the Kobo
store, with reading progress synced back to CWA.

1. **Admin → Edit Basic Configuration → Feature Configuration**:
   - enable **Kobo sync**;
   - optionally enable **Proxy unknown requests to Kobo Store** to keep the
     official store working on the device.
2. **Admin → Edit Basic Configuration → Server Configuration**: set **Server
   External Port** to `8083` (or the port you chose in the add-on *Network*
   section), so the device receives URLs it can reach.
3. Open your **user profile**, under **Kobo Sync Token** click
   **Create/View** and copy the `api_endpoint=...` line.
4. Connect the Kobo to a computer via USB and edit
   `.kobo/Kobo/Kobo eReader.conf`. In the `[OneStoreServices]` section,
   replace the existing `api_endpoint=` line with the one from step 3.
5. Eject the device and tap **Sync**.

Tips:

- Add books to a **shelf** marked "Sync this shelf with Kobo" if you only want
  part of the library on the device (option in the user profile).
- The Kobo must reach Home Assistant on port 8083: use the LAN IP address, not
  `homeassistant.local`, if your Wi-Fi does not resolve mDNS names.
- After a factory reset or firmware update, the `api_endpoint` line may need
  to be set again.

## Data, backups and updates

| What                                   | Where (host)                 | In HA backups            |
| -------------------------------------- | ---------------------------- | ------------------------ |
| App settings, users, Kobo tokens (`app.db`, `cwa.db`, logs) | add-on `/data/cwa-config` | Yes (add-on backup) |
| Books and `metadata.db`                | `library_path`               | Only if you include the `share` / `media` folder |
| Ingest queue                           | `ingest_path`                | Only if you include the `share` / `media` folder |

Application data survives add-on updates and restarts. Uninstalling the
add-on removes `/data`, but never touches the library in `/share` or `/media`.

## Using it with Shelfmark

The **Shelfmark** add-on from the same repository can search and
download books straight into the ingest folder: by default it saves to
`/media/calibre/ingest`, so with `ingest_path: /media/calibre/ingest` every
download is imported automatically. If you keep the default
`/share/calibre/ingest`, set Shelfmark's `download_path` to the same folder.

## Security notes

The add-on needs the `SYS_ADMIN` capability and has AppArmor disabled. Both
are required to bind-mount the folders you choose into the paths CWA expects
(`/calibre-library`, `/cwa-book-ingest`, `/config`). A bind mount is used
instead of a symlink so that the inotify-based ingest watcher works reliably.
This lowers the add-on's security rating in Home Assistant.

## Troubleshooting

- **Add-on stops right after starting:** open the **Log** tab and look for
  `[ha-setup] ERROR:` lines (invalid paths, overlapping folders, mount
  failures).
- **Books dropped in the ingest folder are not imported:** make sure the
  files are completely copied, check the CWA logs page in the web UI, and
  verify that the ingest folder is not on network storage that lacks inotify
  support.
- **Permission errors in Samba:** use `puid: 0` / `pgid: 0`, or restart the
  add-on after changing them so ownership is fixed.

[cwa]: https://github.com/crocodilestick/Calibre-Web-Automated
