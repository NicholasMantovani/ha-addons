# ==============================================================================
# Home Assistant add-on wrapper for Shelfmark (standard image)
# Upstream: https://github.com/calibrain/shelfmark
#
# BUILD_FROM is injected by the Supervisor from build.yaml (per architecture).
# The default below allows a plain `docker build` and is kept in sync by
# .github/workflows/sync-upstream.yml.
# ==============================================================================
ARG BUILD_FROM=ghcr.io/calibrain/shelfmark:v1.7.0
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION

# jq is needed to read /data/options.json
# hadolint ignore=DL3008
RUN set -eux; \
    if ! command -v jq >/dev/null 2>&1; then \
        apt-get update; \
        apt-get install -y --no-install-recommends jq; \
        rm -rf /var/lib/apt/lists/*; \
    fi

COPY rootfs/ /

# Strip CRLF (Windows checkouts) and make the launcher executable
RUN sed -i 's/\r$//' /usr/local/bin/ha-run.sh \
    && chmod 0755 /usr/local/bin/ha-run.sh

# The upstream image keeps ENTRYPOINT ["/usr/bin/dumb-init", "--"] and its own
# HEALTHCHECK on /api/health. Only the command changes: ha-run.sh translates
# the add-on options into environment variables, then execs /app/entrypoint.sh.
WORKDIR /app
CMD ["/usr/local/bin/ha-run.sh"]

LABEL \
    io.hass.name="Shelfmark" \
    io.hass.description="Shelfmark packaged as a Home Assistant add-on" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="Shelfmark (Home Assistant add-on)" \
    org.opencontainers.image.source="https://github.com/NicholasMantovani/ha-addons" \
    org.opencontainers.image.licenses="MIT"
