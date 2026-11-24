#!/usr/bin/with-contenv bash
# shellcheck shell=bash
# ==============================================================================
# Home Assistant add-on setup for Calibre-Web Automated
#
# Executed by the s6-rc oneshot "init-ha-setup", which runs BEFORE the whole
# LinuxServer.io / CWA init chain:
#
#   base -> init-ha-setup -> init-migrations -> init-adduser -> ... -> init-config
#        -> cwa-init -> calibre-binaries-setup / cwa-auto-library
#        -> svc-calibre-web-automated -> cwa-ingest-service ...
#
# Why not /etc/cont-init.d or /custom-cont-init.d?
#   - /etc/cont-init.d (s6 "legacy-cont-init") only depends on "base", so it
#     runs in PARALLEL with the LSIO init services: PUID/PGID could be applied
#     before we export them and CWA could start before the bind mounts exist.
#   - /custom-cont-init.d runs AFTER init-adduser/init-config, too late for
#     PUID/PGID and for relocating /config.
#
# Responsibilities:
#   1. Read the add-on options from /data/options.json (jq).
#   2. Export PUID / PGID / TZ to the s6 container environment so that every
#      following `with-contenv` service (init-adduser, CWA...) sees them.
#   3. Persist /config (app.db, users, Kobo settings) into /data/cwa-config.
#   4. Create the library / ingest directories with the right ownership and
#      bind-mount them on /calibre-library and /cwa-book-ingest. A bind mount
#      (not a symlink) keeps inotify-based ingest detection working.
# ==============================================================================
set -euo pipefail

readonly OPTIONS_FILE="/data/options.json"
readonly PERSISTENT_CONFIG="/data/cwa-config"
readonly CONTAINER_ENV_DIR="/run/s6/container_environment"

readonly CWA_CONFIG="/config"
readonly CWA_LIBRARY="/calibre-library"
readonly CWA_INGEST="/cwa-book-ingest"

log()   { echo "[ha-setup] $*"; }
warn()  { echo "[ha-setup] WARNING: $*" >&2; }
fatal() { echo "[ha-setup] ERROR: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
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

# True if $1 is equal to, or nested inside, $2.
is_within() {
    [[ "$1" == "$2" || "$1" == "$2"/* ]]
}

# Write a variable to the s6 container environment (read by `with-contenv`).
export_env() {
    local name="$1" value="$2"
    printf '%s' "${value}" > "${CONTAINER_ENV_DIR}/${name}"
    export "${name}=${value}"
}

# Create a directory and make sure it is owned by PUID:PGID.
# Recursive chown only happens when the top-level owner differs (first run or
# PUID/PGID change), so restarts with a large library stay fast.
ensure_dir() {
    local path="$1"

    if [[ ! -d "${path}" ]]; then
        log "Creating directory ${path}"
        mkdir -p -- "${path}"
    fi

    if [[ "$(stat -c '%u:%g' -- "${path}")" != "${PUID}:${PGID}" ]]; then
        log "Setting ownership of ${path} to ${PUID}:${PGID} (recursive, may take a while)"
        chown -R "${PUID}:${PGID}" -- "${path}"
    fi

    chmod u+rwx,g+rwx -- "${path}"
}

# Bind-mount $1 on $2, idempotently.
bind_mount() {
    local src="$1" dst="$2"

    mkdir -p -- "${dst}"

    if [[ "$(stat -c '%d:%i' -- "${src}")" == "$(stat -c '%d:%i' -- "${dst}")" ]]; then
        log "${dst} is already bound to ${src}"
        return 0
    fi

    if ! mount --bind "${src}" "${dst}"; then
        fatal "Unable to bind-mount ${src} on ${dst}. The add-on needs the SYS_ADMIN privilege and AppArmor disabled (see config.yaml)."
    fi
    log "Bound ${src} -> ${dst}"
}

# ------------------------------------------------------------------------------
# 1. Read options
# ------------------------------------------------------------------------------
[[ -f "${OPTIONS_FILE}" ]] || fatal "${OPTIONS_FILE} not found: is this running as a Home Assistant add-on?"
[[ -d "${CONTAINER_ENV_DIR}" ]] || fatal "${CONTAINER_ENV_DIR} not found: s6-overlay v3 is required."

LIBRARY_PATH="$(validate_share_path library_path "$(get_option library_path)")"
INGEST_PATH="$(validate_share_path ingest_path "$(get_option ingest_path)")"
OPT_PUID="$(get_option puid)"
OPT_PGID="$(get_option pgid)"
OPT_TZ="$(get_option timezone)"

[[ "${OPT_PUID}" =~ ^[0-9]+$ ]] || fatal "Option 'puid' must be a non-negative integer (got '${OPT_PUID}')."
[[ "${OPT_PGID}" =~ ^[0-9]+$ ]] || fatal "Option 'pgid' must be a non-negative integer (got '${OPT_PGID}')."

if is_within "${INGEST_PATH}" "${LIBRARY_PATH}" || is_within "${LIBRARY_PATH}" "${INGEST_PATH}"; then
    fatal "library_path (${LIBRARY_PATH}) and ingest_path (${INGEST_PATH}) must be separate, non-nested directories: files in the ingest folder are DELETED after import."
fi

if [[ -z "${OPT_TZ}" ]]; then
    OPT_TZ="Etc/UTC"
elif [[ "${OPT_TZ}" == *..* || ! -f "/usr/share/zoneinfo/${OPT_TZ}" ]]; then
    warn "Unknown timezone '${OPT_TZ}', falling back to Etc/UTC."
    OPT_TZ="Etc/UTC"
fi

# ------------------------------------------------------------------------------
# 2. Container environment (consumed by init-adduser and the CWA services)
# ------------------------------------------------------------------------------
export_env PUID "${OPT_PUID}"
export_env PGID "${OPT_PGID}"
export_env TZ "${OPT_TZ}"

# Extra environment variables (option `env_vars`), e.g. NETWORK_SHARE_MODE, TRUSTED_PROXY_COUNT.
# PUID / PGID / TZ have dedicated options and cannot be overridden here.
while IFS= read -r entry; do
    [[ -n "${entry}" ]] || continue
    name="$(jq -r '.name' <<<"${entry}")"
    value="$(jq -r '.value' <<<"${entry}")"
    if [[ ! "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        warn "Ignoring env_vars entry with invalid name '${name}'."
        continue
    fi
    case "${name}" in
        PUID | PGID | TZ)
            warn "Ignoring env_vars entry '${name}': use the dedicated option instead."
            continue
            ;;
    esac
    export_env "${name}" "${value}"
    log "Extra environment variable set: ${name}"
done < <(jq -c '.env_vars[]?' "${OPTIONS_FILE}")

if [[ "${PUID}" == "0" || "${PGID}" == "0" ]]; then
    log "Running with PUID=${PUID} / PGID=${PGID} (root): files are fully accessible via Samba."
fi

# ------------------------------------------------------------------------------
# 3. Persistent application config: /data/cwa-config -> /config
# ------------------------------------------------------------------------------
mkdir -p -- "${PERSISTENT_CONFIG}"

# One-time seed: if /data/cwa-config is empty but the image's /config volume
# already contains files, carry them over before hiding them with the mount.
if [[ -z "$(ls -A -- "${PERSISTENT_CONFIG}")" && -d "${CWA_CONFIG}" && -n "$(ls -A -- "${CWA_CONFIG}" 2>/dev/null)" ]]; then
    log "Seeding ${PERSISTENT_CONFIG} with the existing content of ${CWA_CONFIG}"
    cp -a -- "${CWA_CONFIG}/." "${PERSISTENT_CONFIG}/"
fi

ensure_dir "${PERSISTENT_CONFIG}"
bind_mount "${PERSISTENT_CONFIG}" "${CWA_CONFIG}"

# ------------------------------------------------------------------------------
# 4. Library and ingest folders
# ------------------------------------------------------------------------------
ensure_dir "${LIBRARY_PATH}"
ensure_dir "${INGEST_PATH}"

bind_mount "${LIBRARY_PATH}" "${CWA_LIBRARY}"
bind_mount "${INGEST_PATH}" "${CWA_INGEST}"

log "Setup complete:"
log "  config  : ${PERSISTENT_CONFIG} -> ${CWA_CONFIG}"
log "  library : ${LIBRARY_PATH} -> ${CWA_LIBRARY}"
log "  ingest  : ${INGEST_PATH} -> ${CWA_INGEST}"
log "  PUID=${PUID} PGID=${PGID} TZ=${TZ}"
