# ==============================================================================
# Home Assistant add-on wrapper for Calibre-Web Automated
# Upstream: https://github.com/crocodilestick/Calibre-Web-Automated
#
# BUILD_FROM is injected by the Supervisor from build.yaml (per architecture).
# The default below allows a plain `docker build` and is kept in sync by
# .github/workflows/sync-upstream.yml.
# ==============================================================================
ARG BUILD_FROM=crocodilestick/calibre-web-automated:v4.0.8
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION

# Add-on overlay:
#   /etc/s6-overlay/s6-rc.d/init-ha-setup/            s6-rc oneshot definition
#   /etc/s6-overlay/s6-rc.d/user/contents.d/          enables it
#   /etc/s6-overlay/s6-rc.d/init-migrations/dependencies.d/init-ha-setup
#                                                     runs it BEFORE the LSIO init chain
#   /etc/s6-overlay/scripts/00-ha-setup.sh            the actual setup script
COPY rootfs/ /

# - Strip CRLF in case the repo was checked out on Windows without .gitattributes
# - Make the script executable (git on Windows does not preserve the +x bit)
# - jq ships with the LinuxServer.io base image; install it only if missing
# hadolint ignore=DL3008
RUN set -eux; \
    find /etc/s6-overlay/s6-rc.d/init-ha-setup /etc/s6-overlay/scripts/00-ha-setup.sh \
        -type f -exec sed -i 's/\r$//' {} +; \
    chmod 0755 /etc/s6-overlay/scripts/00-ha-setup.sh; \
    if ! command -v jq >/dev/null 2>&1; then \
        apt-get update; \
        apt-get install -y --no-install-recommends jq; \
        rm -rf /var/lib/apt/lists/*; \
    fi

HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=3 \
    CMD curl -fsL --connect-timeout 2 --max-time 8 -o /dev/null http://127.0.0.1:8083/ || exit 1

LABEL \
    io.hass.name="Calibre-Web Automated" \
    io.hass.description="Calibre-Web Automated packaged as a Home Assistant add-on" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="Calibre-Web Automated (Home Assistant add-on)" \
    org.opencontainers.image.source="https://github.com/NicholasMantovani/ha-addons" \
    org.opencontainers.image.licenses="GPL-3.0"
