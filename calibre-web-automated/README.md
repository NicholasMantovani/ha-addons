# Home Assistant Add-on: Calibre-Web Automated

![Supports aarch64](https://img.shields.io/badge/aarch64-yes-green.svg)
![Supports amd64](https://img.shields.io/badge/amd64-yes-green.svg)

[Calibre-Web Automated][cwa] is a web app to browse, read and manage a Calibre
e-book library, with:

- automatic ingest: drop books in a folder and they are imported;
- automatic conversion to your preferred format;
- metadata and cover enforcement;
- OPDS feed for e-reader apps;
- Kobo Sync.

Books are stored in `/share` or `/media`, so they are reachable via Samba and
the Media Browser. Application settings are kept in the add-on data and
included in Home Assistant backups.

Opens inside Home Assistant through **Ingress** (also remotely), plus a
direct LAN port.

See the **Documentation** tab for setup, OPDS and Kobo Sync instructions.

[cwa]: https://github.com/crocodilestick/Calibre-Web-Automated
