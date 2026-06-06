#!/bin/bash
# =============================================================================
# krdos-update  —  KrdOS self-update via GitHub Releases
# Installed to: /usr/local/bin/krdos-update
# Usage:  krdos-update          # check + apply if newer version exists
#         krdos-update --check  # only print status, don't install
#         krdos-update --force  # install even if same version
# =============================================================================

# ── CONFIGURE THIS ────────────────────────────────────────────────────────────
GITHUB_REPO="escscripts/krdos"
# Example:   GITHUB_REPO="meeru/krdos"
# ─────────────────────────────────────────────────────────────────────────────

INSTALL_DIR="/opt/krdos"
VERSION_FILE="$INSTALL_DIR/version"
SERVICE_NAME="krdos-ui"
TMP_DIR="/tmp/krdos-update-$$"
ASSET_NAME="krdos-bundle.tar.gz"
CHECKSUM_NAME="krdos-bundle.tar.gz.sha256"

# Colours
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
CYN='\033[0;36m'; BLD='\033[1m'; RST='\033[0m'

info()  { echo -e "${CYN}[UPDATE]${RST} $*"; }
ok()    { echo -e "${GRN}[  OK  ]${RST} $*"; }
warn()  { echo -e "${YLW}[ WARN ]${RST} $*"; }
err()   { echo -e "${RED}[ERROR ]${RST} $*"; }
die()   { err "$*"; cleanup; exit 1; }

cleanup() { rm -rf "$TMP_DIR" 2>/dev/null; }
trap cleanup EXIT

# ── Parse flags ───────────────────────────────────────────────────────────────
CHECK_ONLY=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --force) FORCE=1 ;;
  esac
done

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ "$GITHUB_REPO" == *"REPLACE_WITH"* ]]; then
  die "Edit /usr/local/bin/krdos-update and set GITHUB_REPO to your GitHub repo (e.g. meeru/krdos)"
fi

for cmd in curl tar sha256sum systemctl; do
  command -v "$cmd" &>/dev/null || die "Required command not found: $cmd"
done

echo
echo -e "${BLD}╔═══════════════════════════════════════╗${RST}"
echo -e "${BLD}║       KrdOS Self-Update System        ║${RST}"
echo -e "${BLD}╚═══════════════════════════════════════╝${RST}"
echo

# ── Read current version ──────────────────────────────────────────────────────
CURRENT_VERSION="none"
if [[ -f "$VERSION_FILE" ]]; then
  CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
fi
info "Current version : ${BLD}${CURRENT_VERSION}${RST}"

# ── Fetch latest release info from GitHub API ─────────────────────────────────
info "Checking GitHub for latest release..."
API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

RELEASE_JSON=$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  "$API_URL" 2>/dev/null)

if [[ -z "$RELEASE_JSON" ]]; then
  die "Could not reach GitHub API. Check your internet connection."
fi

REMOTE_VERSION=$(echo "$RELEASE_JSON" | grep -oP '"name":\s*"\K[^"]+' | head -1)
BUNDLE_URL=$(echo "$RELEASE_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]+' \
  | grep "${ASSET_NAME}$" | head -1)
CHECKSUM_URL=$(echo "$RELEASE_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]+' \
  | grep "${CHECKSUM_NAME}$" | head -1)
SETUP_URL=$(echo "$RELEASE_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]+' \
  | grep "setup\.sh$" | head -1)

if [[ -z "$BUNDLE_URL" ]]; then
  die "No '${ASSET_NAME}' found in the latest release. Has a build been published yet?"
fi

info "Latest release  : ${BLD}${REMOTE_VERSION}${RST}"
info "Bundle URL      : $BUNDLE_URL"

# ── Version comparison ────────────────────────────────────────────────────────
if [[ "$CURRENT_VERSION" == "$REMOTE_VERSION" && "$FORCE" -eq 0 ]]; then
  ok "Already up to date (${CURRENT_VERSION}). Use --force to reinstall."
  exit 0
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo
  echo -e "${YLW}Update available:${RST} ${CURRENT_VERSION} → ${REMOTE_VERSION}"
  echo "Run 'krdos-update' to install."
  exit 0
fi

# ── Confirm (skip if non-interactive) ────────────────────────────────────────
if [[ -t 0 && "$FORCE" -eq 0 ]]; then
  echo
  echo -e "Update ${YLW}${CURRENT_VERSION}${RST} → ${GRN}${REMOTE_VERSION}${RST}"
  read -r -p "Apply update now? [Y/n] " REPLY
  REPLY="${REPLY:-Y}"
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    info "Update cancelled."
    exit 0
  fi
fi

# ── Download ──────────────────────────────────────────────────────────────────
mkdir -p "$TMP_DIR"
info "Downloading bundle..."
curl -fSL --progress-bar -o "$TMP_DIR/${ASSET_NAME}" "$BUNDLE_URL" \
  || die "Download failed."

# Verify checksum if available
if [[ -n "$CHECKSUM_URL" ]]; then
  info "Verifying checksum..."
  curl -fsSL -o "$TMP_DIR/${CHECKSUM_NAME}" "$CHECKSUM_URL" \
    || warn "Could not download checksum file — skipping verification."

  if [[ -f "$TMP_DIR/${CHECKSUM_NAME}" ]]; then
    EXPECTED=$(awk '{print $1}' "$TMP_DIR/${CHECKSUM_NAME}")
    ACTUAL=$(sha256sum "$TMP_DIR/${ASSET_NAME}" | awk '{print $1}')
    if [[ "$EXPECTED" != "$ACTUAL" ]]; then
      die "Checksum mismatch! Expected: $EXPECTED  Got: $ACTUAL  Download may be corrupt."
    fi
    ok "Checksum verified."
  fi
fi

# Download updated setup.sh if available
if [[ -n "$SETUP_URL" ]]; then
  info "Downloading setup.sh..."
  curl -fsSL -o "$TMP_DIR/setup.sh" "$SETUP_URL" || warn "Could not download setup.sh"
fi

# ── Extract ───────────────────────────────────────────────────────────────────
info "Extracting bundle..."
tar -xzf "$TMP_DIR/${ASSET_NAME}" -C "$TMP_DIR/" \
  || die "Failed to extract bundle."

BUNDLE_DIR="$TMP_DIR/bundle"
if [[ ! -d "$BUNDLE_DIR" ]]; then
  die "Unexpected tarball structure — 'bundle/' directory not found."
fi

if [[ ! -f "$BUNDLE_DIR/krdos" ]]; then
  die "Binary 'krdos' not found in extracted bundle."
fi

# ── Backup current installation ───────────────────────────────────────────────
BACKUP_DIR="/opt/krdos-backup-$(date +%Y%m%d-%H%M%S)"
if [[ -d "$INSTALL_DIR" ]]; then
  info "Backing up current installation to $BACKUP_DIR ..."
  cp -a "$INSTALL_DIR" "$BACKUP_DIR" \
    && ok "Backup created: $BACKUP_DIR" \
    || warn "Backup failed — continuing anyway."
fi

# ── Stop service ──────────────────────────────────────────────────────────────
info "Stopping krdos-ui service..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sleep 1
# Kill any lingering flutter process
pkill -f "$INSTALL_DIR/krdos" 2>/dev/null || true
sleep 1

# ── Install ───────────────────────────────────────────────────────────────────
info "Installing new bundle to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# Sync files (rsync preferred, fallback cp)
if command -v rsync &>/dev/null; then
  rsync -a --delete "$BUNDLE_DIR/" "$INSTALL_DIR/" \
    || die "rsync failed — trying fallback."
else
  cp -a "$BUNDLE_DIR/." "$INSTALL_DIR/" \
    || die "Copy failed."
fi

chmod +x "$INSTALL_DIR/krdos"
ok "Bundle installed."

# Run setup.sh from release if downloaded (updates services/scripts/config)
if [[ -f "$TMP_DIR/setup.sh" ]]; then
  info "Running setup.sh from this release (updates services & config)..."
  chmod +x "$TMP_DIR/setup.sh"
  bash "$TMP_DIR/setup.sh" --update-only 2>&1 | sed 's/^/  /' || \
    warn "setup.sh reported errors — continuing."
fi

# ── Record new version ────────────────────────────────────────────────────────
echo "$REMOTE_VERSION" > "$VERSION_FILE"
ok "Version recorded: $REMOTE_VERSION"

# ── Prune old backups (keep last 3) ──────────────────────────────────────────
ls -dt /opt/krdos-backup-* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null || true

# ── Restart service ───────────────────────────────────────────────────────────
info "Starting krdos-ui service..."
systemctl start "$SERVICE_NAME" \
  && ok "krdos-ui restarted — new version is live." \
  || {
    err "Service failed to start. Attempting rollback..."
    if [[ -d "$BACKUP_DIR" ]]; then
      cp -a "$BACKUP_DIR/." "$INSTALL_DIR/"
      systemctl start "$SERVICE_NAME" && warn "Rolled back to previous version." \
        || err "Rollback start also failed. Check: journalctl -u krdos-ui"
    fi
    exit 1
  }

echo
echo -e "${GRN}╔═══════════════════════════════════════╗${RST}"
echo -e "${GRN}║   KrdOS updated successfully!         ║${RST}"
echo -e "${GRN}║   Version: ${REMOTE_VERSION}${RST}"
echo -e "${GRN}╚═══════════════════════════════════════╝${RST}"
echo
