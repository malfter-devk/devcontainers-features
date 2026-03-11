#!/bin/bash
# -----------------------------------------------------------------------------
# Dev Container Feature: opencode
# Installs the opencode CLI from GitHub Releases.
# -----------------------------------------------------------------------------
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — adjust these if the repository moves
# ---------------------------------------------------------------------------
GITHUB_OWNER="anomalyco"
GITHUB_REPO="opencode"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="opencode"
GITHUB_API_BASE="https://api.github.com"
GITHUB_RELEASES_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases"

# ---------------------------------------------------------------------------
# Read the version option injected by the devcontainer feature runtime.
# The env var name is the uppercased option id from devcontainer-feature.json.
# ---------------------------------------------------------------------------
REQUESTED_VERSION="${VERSION:-"latest"}"

# ---------------------------------------------------------------------------
# Helper: print an informational message
# ---------------------------------------------------------------------------
info() {
    echo "[opencode-install] INFO: $*"
}

# ---------------------------------------------------------------------------
# Helper: print an error message to stderr and exit
# ---------------------------------------------------------------------------
err() {
    echo "[opencode-install] ERROR: $*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Ensure curl is available, installing it via the distro package manager if not.
# Must be called after detect_os.
# ---------------------------------------------------------------------------
ensure_http_client() {
    if command -v curl > /dev/null 2>&1 || command -v wget > /dev/null 2>&1; then
        return 0
    fi

    info "Neither 'curl' nor 'wget' found — attempting to install curl..."

    case "${OS_ID}" in
        debian | ubuntu)
            apt-get update -y -qq
            apt-get install -y -qq --no-install-recommends curl ca-certificates
            ;;
        opensuse* | sles)
            zypper --non-interactive install --no-recommends curl ca-certificates
            ;;
        *)
            case "${OS_ID_LIKE}" in
                *debian* | *ubuntu*)
                    apt-get update -y -qq
                    apt-get install -y -qq --no-install-recommends curl ca-certificates
                    ;;
                *suse* | *opensuse*)
                    zypper --non-interactive install --no-recommends curl ca-certificates
                    ;;
                *)
                    err "Cannot install curl: unknown OS '${OS_ID}'. Please install curl or wget manually."
                    ;;
            esac
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Detect the HTTP client available on this image (curl preferred, wget fallback)
# ---------------------------------------------------------------------------
detect_http_client() {
    if command -v curl > /dev/null 2>&1; then
        HTTP_CLIENT="curl"
    elif command -v wget > /dev/null 2>&1; then
        HTTP_CLIENT="wget"
    else
        err "Neither 'curl' nor 'wget' is available after attempted install."
    fi
    info "Using HTTP client: ${HTTP_CLIENT}"
}

# ---------------------------------------------------------------------------
# Perform an HTTPS GET request and write the response body to stdout.
# Accepts an optional second argument for the Accept header.
# ---------------------------------------------------------------------------
http_get() {
    URL="$1"
    ACCEPT="${2:-}"

    # Build optional GitHub token header for rate-limit mitigation.
    # Uses OPENCODE_GITHUB_TOKEN (not GITHUB_TOKEN) to avoid accidentally
    # sending the repo-scoped Actions token to an external GitHub repository,
    # which would result in a 403 response.
    AUTH_HEADER=""
    if [ -n "${OPENCODE_GITHUB_TOKEN:-}" ]; then
        AUTH_HEADER="Authorization: token ${OPENCODE_GITHUB_TOKEN}"
    fi

    if [ "${HTTP_CLIENT}" = "curl" ]; then
        CURL_OPTS="-fsSL"
        if [ -n "${AUTH_HEADER}" ]; then
            curl ${CURL_OPTS} -H "${AUTH_HEADER}" ${ACCEPT:+-H "Accept: ${ACCEPT}"} "${URL}"
        else
            curl ${CURL_OPTS} ${ACCEPT:+-H "Accept: ${ACCEPT}"} "${URL}"
        fi
    else
        # wget
        WGET_OPTS="--quiet -O -"
        if [ -n "${AUTH_HEADER}" ]; then
            wget ${WGET_OPTS} --header="${AUTH_HEADER}" ${ACCEPT:+--header="Accept: ${ACCEPT}"} "${URL}"
        else
            wget ${WGET_OPTS} ${ACCEPT:+--header="Accept: ${ACCEPT}"} "${URL}"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Detect the OS distribution via /etc/os-release
# Sets OS_ID to one of: debian, ubuntu, opensuse, unknown
# ---------------------------------------------------------------------------
detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID=$(echo "${ID:-unknown}" | tr '[:upper:]' '[:lower:]')
        OS_ID_LIKE=$(echo "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')
    else
        OS_ID="unknown"
        OS_ID_LIKE=""
    fi
    info "Detected OS: ${OS_ID} (like: ${OS_ID_LIKE:-n/a})"
}

# ---------------------------------------------------------------------------
# Detect the CPU architecture and map it to the GitHub release asset suffix.
# Release asset names follow the pattern: opencode-linux-{x64|arm64}.tar.gz
# Sets ARCH (raw uname -m) and ASSET_ARCH (value used in asset filenames).
# ---------------------------------------------------------------------------
detect_arch() {
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64)
            ASSET_ARCH="x64"
            ;;
        aarch64 | arm64)
            ASSET_ARCH="arm64"
            ;;
        *)
            err "Unsupported architecture: ${ARCH}. Only x86_64 and aarch64 are supported."
            ;;
    esac
    info "Detected architecture: ${ARCH} -> asset arch: ${ASSET_ARCH}"
}

# ---------------------------------------------------------------------------
# Resolve the requested version string to an exact tag.
# Sets RESOLVED_VERSION (without leading "v") and TAG (with leading "v").
# ---------------------------------------------------------------------------
resolve_version() {
    info "Resolving version: '${REQUESTED_VERSION}'"

    if [ "${REQUESTED_VERSION}" = "latest" ]; then
        # Query the GitHub Releases API for the latest stable release
        RELEASE_JSON=$(http_get \
            "${GITHUB_API_BASE}/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest" \
            "application/vnd.github+json" \
        ) || err "Failed to query GitHub Releases API. Check your network connection."

        TAG=$(echo "${RELEASE_JSON}" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"')
    else
        # Strip a leading "v" if present, then re-add it to normalise
        CLEAN_VERSION=$(echo "${REQUESTED_VERSION}" | sed 's/^v//')
        TAG="v${CLEAN_VERSION}"
    fi

    if [ -z "${TAG}" ]; then
        err "Could not determine a release tag for version '${REQUESTED_VERSION}'."
    fi

    # Remove the leading "v" to get a plain semver string
    RESOLVED_VERSION=$(echo "${TAG}" | sed 's/^v//')
    info "Resolved tag: ${TAG} (version: ${RESOLVED_VERSION})"
}

# ---------------------------------------------------------------------------
# Check whether opencode is already installed at the desired version.
# Returns 0 if already installed, 1 otherwise.
# ---------------------------------------------------------------------------
is_already_installed() {
    if command -v "${BINARY_NAME}" > /dev/null 2>&1; then
        INSTALLED_VERSION=$("${BINARY_NAME}" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
        if [ "${INSTALLED_VERSION}" = "${RESOLVED_VERSION}" ]; then
            info "opencode ${RESOLVED_VERSION} is already installed. Nothing to do."
            return 0
        fi
        info "opencode ${INSTALLED_VERSION:-unknown} is installed but version ${RESOLVED_VERSION} was requested. Reinstalling."
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Download a URL to a file, using the detected HTTP client.
# ---------------------------------------------------------------------------
download_file() {
    URL="$1"
    DEST="$2"
    info "Downloading ${URL} -> ${DEST}"

    if [ "${HTTP_CLIENT}" = "curl" ]; then
        if [ -n "${OPENCODE_GITHUB_TOKEN:-}" ]; then
            curl -fsSL -H "Authorization: token ${OPENCODE_GITHUB_TOKEN}" -o "${DEST}" "${URL}"
        else
            curl -fsSL -o "${DEST}" "${URL}"
        fi
    else
        if [ -n "${OPENCODE_GITHUB_TOKEN:-}" ]; then
            wget --quiet --header="Authorization: token ${OPENCODE_GITHUB_TOKEN}" -O "${DEST}" "${URL}"
        else
            wget --quiet -O "${DEST}" "${URL}"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Ensure tar is available for extracting .tar.gz archives.
# Must be called after detect_os.
# ---------------------------------------------------------------------------
ensure_tar() {
    if command -v tar > /dev/null 2>&1; then
        return 0
    fi
    info "'tar' not found — attempting to install..."
    case "${OS_ID}" in
        debian | ubuntu)
            apt-get update -y -qq
            apt-get install -y -qq --no-install-recommends tar
            ;;
        opensuse* | sles)
            zypper --non-interactive install --no-recommends tar gzip
            ;;
        *)
            case "${OS_ID_LIKE}" in
                *debian* | *ubuntu*)
                    apt-get update -y -qq
                    apt-get install -y -qq --no-install-recommends tar
                    ;;
                *suse* | *opensuse*)  zypper --non-interactive install --no-recommends tar gzip ;;
                *) err "Cannot install tar: unknown OS '${OS_ID}'. Please install tar manually." ;;
            esac
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Download the .tar.gz asset, extract the binary, and install it.
# Asset naming convention: opencode-linux-{x64|arm64}.tar.gz
# The archive contains a single file named 'opencode' at its root.
# ---------------------------------------------------------------------------
install_binary() {
    ASSET_NAME="${BINARY_NAME}-linux-${ASSET_ARCH}.tar.gz"
    DOWNLOAD_URL="${GITHUB_RELEASES_URL}/download/${TAG}/${ASSET_NAME}"

    TMP_ARCHIVE="${TMP_DIR}/${ASSET_NAME}"

    # Attempt download — give a clear error if it fails (e.g. no network or 404)
    download_file "${DOWNLOAD_URL}" "${TMP_ARCHIVE}" \
        || err "Download failed. URL: ${DOWNLOAD_URL}. Check your network and that the release/tag exists."

    # Verify the file is not empty
    if [ ! -s "${TMP_ARCHIVE}" ]; then
        err "Downloaded archive is empty. The asset '${ASSET_NAME}' may not exist for version ${TAG}."
    fi

    # Extract the binary from the archive
    ensure_tar

    # Verify the archive contains the expected binary before extracting
    ARCHIVE_CONTENTS=$(tar -tzf "${TMP_ARCHIVE}" 2>/dev/null) \
        || err "Failed to list archive contents — the file may be corrupt or not a valid tar.gz."

    # Accept the binary either at root level or inside a single subdirectory
    BINARY_PATH_IN_ARCHIVE=$(echo "${ARCHIVE_CONTENTS}" | grep -E "(^|/)${BINARY_NAME}$" | head -1)
    if [ -z "${BINARY_PATH_IN_ARCHIVE}" ]; then
        err "Expected binary '${BINARY_NAME}' not found in archive '${ASSET_NAME}'. Archive contents: $(echo "${ARCHIVE_CONTENTS}" | tr '\n' ' ')"
    fi
    info "Found binary in archive at: ${BINARY_PATH_IN_ARCHIVE}"

    tar -xzf "${TMP_ARCHIVE}" -C "${TMP_DIR}"

    TMP_BINARY="${TMP_DIR}/${BINARY_PATH_IN_ARCHIVE}"
    if [ ! -f "${TMP_BINARY}" ]; then
        err "Binary '${BINARY_NAME}' not found at expected path '${TMP_BINARY}' after extraction."
    fi

    # Make executable and move into place
    chmod +x "${TMP_BINARY}"
    mv "${TMP_BINARY}" "${INSTALL_DIR}/${BINARY_NAME}"
    info "Installed binary to ${INSTALL_DIR}/${BINARY_NAME}."
}

# ---------------------------------------------------------------------------
# OS-aware installation entry point.
# For Debian/Ubuntu and OpenSUSE we still fall back to the binary download
# because opencode is not (yet) available in official distro repositories.
# If a distro package ever becomes available, add the package-manager path here.
# ---------------------------------------------------------------------------
install_opencode() {
    case "${OS_ID}" in
        debian | ubuntu)
            info "OS is Debian/Ubuntu. Installing via binary download."
            install_binary
            ;;
        opensuse* | sles)
            info "OS is OpenSUSE/SLES. Installing via binary download."
            install_binary
            ;;
        *)
            # Check ID_LIKE as a fallback (e.g. "debian" family)
            case "${OS_ID_LIKE}" in
                *debian* | *ubuntu*)
                    info "OS is Debian-like (${OS_ID}). Installing via binary download."
                    install_binary
                    ;;
                *suse* | *opensuse*)
                    info "OS is SUSE-like (${OS_ID}). Installing via binary download."
                    install_binary
                    ;;
                *)
                    info "Unknown OS '${OS_ID}'. Attempting binary download as fallback."
                    install_binary
                    ;;
            esac
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Verify the installation succeeded and report the installed version
# ---------------------------------------------------------------------------
verify_installation() {
    if ! command -v "${BINARY_NAME}" > /dev/null 2>&1; then
        err "Installation appeared to succeed but '${BINARY_NAME}' is not found in PATH."
    fi

    INSTALLED_OUTPUT=$("${BINARY_NAME}" --version 2>&1 || true)
    INSTALLED_VER=$(echo "${INSTALLED_OUTPUT}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)

    if [ -z "${INSTALLED_VER}" ]; then
        info "Could not parse version from '${BINARY_NAME} --version' output: ${INSTALLED_OUTPUT}"
        info "Installation may still be successful — please verify manually."
        return
    fi

    if [ "${INSTALLED_VER}" != "${RESOLVED_VERSION}" ]; then
        err "Version mismatch after install: expected ${RESOLVED_VERSION}, got ${INSTALLED_VER}."
    fi

    info "Successfully installed opencode ${INSTALLED_VER} at ${INSTALL_DIR}/${BINARY_NAME}."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
info "Starting opencode feature installation (requested version: '${REQUESTED_VERSION}')..."

# Create a single temporary directory for the entire script lifetime and
# register a global cleanup trap. This ensures cleanup happens exactly
# once, regardless of how many helper functions use TMP_DIR.
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

detect_os
ensure_http_client
detect_http_client
detect_arch
resolve_version

# Idempotency check: skip installation if the right version is already present
if is_already_installed; then
    exit 0
fi

install_opencode
verify_installation

info "Done."
