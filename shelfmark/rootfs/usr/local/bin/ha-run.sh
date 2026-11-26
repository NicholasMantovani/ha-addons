#!/usr/bin/env bash
# shellcheck shell=bash
# ==============================================================================
# Home Assistant add-on launcher for Shelfmark
#
# Translates /data/options.json into the environment variables understood by
# Shelfmark, then hands over to the upstream /app/entrypoint.sh (which handles
# PUID/PGID, ownership, Tor and starts the app).
#
# No bind mounts are needed:
#   /config   <- add-on config folder (map: addon_config), Shelfmark default
#   downloads <- INGEST_DIR pointing anywhere inside /share or /media
# ==============================================================================
set -euo pipefail

readonly OPTIONS_FILE="/data/options.json"

log()   { echo "[ha-run] $*"; }
warn()  { echo "[ha-run] WARNING: $*" >&2; }
fatal() { echo "[ha-run] ERROR: $*" >&2; exit 1; }

get_option() {
    jq -r --arg key "$1" '.[$key] // empty' "${OPTIONS_FILE}"
}

# Normalise a user supplied path and make sure it lives inside /share or /media.
validate_share_path() {
    local name="$1" raw="$2" resolved

    [[ -n "${raw}" ]] || fatal "Option '${name}' is empty."
    [[ "${raw}" == /* ]] || fatal "Option '${name}' must be an absolute path (got '${raw}')."

    resolved="$(realpath -m -- "${raw}")"
    case "${resolved}" in
        /share/?* | /media/?*) ;;
        *) fatal "Option '${name}' must point inside /share or /media (got '${raw}' -> '${resolved}')." ;;
    esac

    printf '%s' "${resolved}"
}

[[ -f "${OPTIONS_FILE}" ]] || fatal "${OPTIONS_FILE} not found: is this running as a Home Assistant add-on?"

# ------------------------------------------------------------------------------
# Basic options
# ------------------------------------------------------------------------------
DOWNLOAD_PATH="$(validate_share_path download_path "$(get_option download_path)")"
OPT_PUID="$(get_option puid)"
OPT_PGID="$(get_option pgid)"
OPT_TZ="$(get_option timezone)"
OPT_NETWORK_MODE="$(get_option network_mode)"
OPT_LOG_LEVEL="$(get_option log_level)"

[[ "${OPT_PUID}" =~ ^[0-9]+$ ]] || fatal "Option 'puid' must be a non-negative integer (got '${OPT_PUID}')."
[[ "${OPT_PGID}" =~ ^[0-9]+$ ]] || fatal "Option 'pgid' must be a non-negative integer (got '${OPT_PGID}')."

if [[ -z "${OPT_TZ}" ]]; then
    OPT_TZ="Etc/UTC"
elif [[ "${OPT_TZ}" == *..* || ! -f "/usr/share/zoneinfo/${OPT_TZ}" ]]; then
    warn "Unknown timezone '${OPT_TZ}', falling back to Etc/UTC."
    OPT_TZ="Etc/UTC"
fi

if [[ ! -d "${DOWNLOAD_PATH}" ]]; then
    log "Creating download directory ${DOWNLOAD_PATH}"
    mkdir -p -- "${DOWNLOAD_PATH}"
fi

export PUID="${OPT_PUID}"
export PGID="${OPT_PGID}"
export TZ="${OPT_TZ}"
export CONFIG_DIR="/config"
export INGEST_DIR="${DOWNLOAD_PATH}"
export LOG_LEVEL="${OPT_LOG_LEVEL^^}"

# ------------------------------------------------------------------------------
# Network mode
# ------------------------------------------------------------------------------
case "${OPT_NETWORK_MODE:-direct}" in
    direct)
        export USING_TOR=false
        ;;
    tor)
        export USING_TOR=true
        log "Network mode: all traffic is routed through Tor."
        ;;
    *)
        fatal "Unsupported network_mode '${OPT_NETWORK_MODE}' (use 'direct' or 'tor')."
        ;;
esac
# WireGuard needs container sysctls that Home Assistant add-ons cannot set.
export USING_WIREGUARD=false

# ------------------------------------------------------------------------------
# Calibre-Web Automated integration
# ------------------------------------------------------------------------------
if [[ "$(get_option calibre_library_check)" == "true" ]]; then
    LIBRARY_PATH="$(validate_share_path calibre_library_path "$(get_option calibre_library_path)")"
    if [[ -f "${LIBRARY_PATH}/metadata.db" ]]; then
        export LIBRARY_CHECK_CALIBRE_ENABLED=true
        export CALIBRE_LIBRARY_DB_PATH="${LIBRARY_PATH}/metadata.db"
        log "Library Check enabled with ${CALIBRE_LIBRARY_DB_PATH}"
    else
        warn "Library Check: ${LIBRARY_PATH}/metadata.db not found, feature left disabled. Start Calibre-Web Automated first or fix calibre_library_path."
    fi
fi

CALIBRE_WEB_URL_OPT="$(get_option calibre_web_url)"
if [[ -n "${CALIBRE_WEB_URL_OPT}" ]]; then
    export CALIBRE_WEB_URL="${CALIBRE_WEB_URL_OPT}"
    log "Library link: ${CALIBRE_WEB_URL}"
fi

# ------------------------------------------------------------------------------
# Front proxy
#
# Shelfmark runs at the root (empty URL_BASE) on 127.0.0.1:8085, like a plain
# install, and nginx (/etc/nginx/ha-shelfmark.conf) fronts it: as-is on the
# direct port (8084), and with the Ingress path put back on the Ingress port
# (8099).
# ------------------------------------------------------------------------------
readonly NGINX_CONF="/etc/nginx/ha-shelfmark.conf"

export FLASK_HOST="127.0.0.1"
export FLASK_PORT="8085"
# Set (even empty) so it overrides a Base Path saved in Shelfmark's settings
export URL_BASE=""

nginx -t -q -c "${NGINX_CONF}" || fatal "Invalid nginx configuration in ${NGINX_CONF}."
nginx -c "${NGINX_CONF}"

# ------------------------------------------------------------------------------
# Extra environment variables (option `env_vars`)
# ------------------------------------------------------------------------------
readonly RESERVED_VARS="PUID PGID TZ CONFIG_DIR INGEST_DIR USING_TOR USING_WIREGUARD FLASK_HOST FLASK_PORT URL_BASE"
while IFS= read -r entry; do
    [[ -n "${entry}" ]] || continue
    name="$(jq -r '.name' <<<"${entry}")"
    value="$(jq -r '.value' <<<"${entry}")"
    if [[ ! "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        warn "Ignoring env_vars entry with invalid name '${name}'."
        continue
    fi
    if [[ " ${RESERVED_VARS} " == *" ${name} "* ]]; then
        warn "Ignoring env_vars entry '${name}': it is managed by the add-on options."
        continue
    fi
    export "${name}=${value}"
    log "Extra environment variable set: ${name}"
done < <(jq -c '.env_vars[]?' "${OPTIONS_FILE}")

log "Starting Shelfmark:"
log "  config    : ${CONFIG_DIR}"
log "  downloads : ${INGEST_DIR}"
log "  network   : ${OPT_NETWORK_MODE:-direct}"
log "  PUID=${PUID} PGID=${PGID} TZ=${TZ} LOG_LEVEL=${LOG_LEVEL}"

cd /app
exec /app/entrypoint.sh
