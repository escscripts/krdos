#!/bin/bash
# =============================================================================
# krdos-update  —  KrdOS self-update via GitHub Releases
# Installed to: /usr/local/bin/krdos-update
#
# Usage:
#   krdos-update            check + apply if a newer version exists
#   krdos-update --check    print status only, never install
#   krdos-update --force    install even if already on latest version
#
# Configuration (never edit this script — edit the conf file instead):
#   /etc/krdos/update.conf     GITHUB_REPO and GITHUB_TOKEN live here
#                              chmod 600, root-only — never committed to git
# =============================================================================

CONFIG_FILE="/etc/krdos/update.conf"
# ── Install directory ──────────────────────────────────────────────────────────
# The Flutter bundle lives in /opt/customos/ — that is the directory the
# krdos-ui launcher script (written by setup.sh) hardcodes at install time.
# /opt/krdos/ is kept ONLY for the version stamp file so the systemd
# update-check service (ConditionPathExists=/opt/krdos/version) works.
INSTALL_DIR="/opt/customos"
VERSION_FILE="/opt/krdos/version"
SERVICE_NAME="krdos-ui"
TMP_DIR="/tmp/krdos-update-$$"
ASSET_NAME="krdos-bundle.tar.gz"
CHECKSUM_NAME="krdos-bundle.tar.gz.sha256"

# Colours — use tput so we get terminal-native sequences (or nothing at all
# if the terminal doesn't support colours, e.g. the KrdOS built-in terminal).
if [ -t 1 ] && command -v tput &>/dev/null && tput setaf 1 &>/dev/null 2>&1; then
  RED=$(tput setaf 1)
  GRN=$(tput setaf 2)
  YLW=$(tput setaf 3)
  CYN=$(tput setaf 6)
  BLD=$(tput bold)
  RST=$(tput sgr0)
else
  RED=''; GRN=''; YLW=''; CYN=''; BLD=''; RST=''
fi

info()  { printf '%s[UPDATE]%s %s\n' "$CYN" "$RST" "$*"; }
ok()    { printf '%s[  OK  ]%s %s\n' "$GRN" "$RST" "$*"; }
warn()  { printf '%s[ WARN ]%s %s\n' "$YLW" "$RST" "$*"; }
err()   { printf '%s[ERROR ]%s %s\n' "$RED" "$RST" "$*"; }
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

# ── Load configuration from /etc/krdos/update.conf ───────────────────────────
# The config file is the single source of truth for repo + token.
# It is chmod 600 / root-only and is NEVER committed to git.
GITHUB_REPO="escscripts/krdos"   # fallback if conf file missing
GITHUB_TOKEN=""                   # NEVER put a real token here — use /etc/krdos/update.conf

if [[ -f "$CONFIG_FILE" ]]; then
  # Parse key=value lines safely — no eval, no sourcing arbitrary code.
  while IFS='=' read -r key value; do
    # Skip blank lines and comments
    [[ -z "$key" || "$key" == \#* ]] && continue
    # Strip inline comments and surrounding whitespace
    value="${value%%#*}"
    value="${value#"${value%%[! ]*}"}"   # ltrim
    value="${value%"${value##*[! ]}"}"   # rtrim
    case "$key" in
      GITHUB_REPO)  GITHUB_REPO="$value"  ;;
      GITHUB_TOKEN) GITHUB_TOKEN="$value" ;;
    esac
  done < "$CONFIG_FILE"
else
  warn "Config file not found: $CONFIG_FILE"
  warn "Create it with: sudo krdos-update-config"
fi

# Allow env-var overrides (useful for one-off manual runs without editing conf)
# e.g.:  GITHUB_TOKEN=ghp_xxx krdos-update
[[ -n "${KRDOS_GITHUB_REPO:-}"  ]] && GITHUB_REPO="$KRDOS_GITHUB_REPO"
[[ -n "${KRDOS_GITHUB_TOKEN:-}" ]] && GITHUB_TOKEN="$KRDOS_GITHUB_TOKEN"

# ── Validate config ───────────────────────────────────────────────────────────
if [[ -z "$GITHUB_REPO" ]]; then
  die "GITHUB_REPO is not set in $CONFIG_FILE\n  Edit the file and add: GITHUB_REPO=owner/repo"
fi

for cmd in curl tar sha256sum systemctl; do
  command -v "$cmd" &>/dev/null || die "Required command not found: $cmd"
done

# ── Build reusable auth header array for curl ─────────────────────────────────
# This is the ONLY place the token is referenced after loading.
# Every curl call uses ${CURL_AUTH[@]} to inject it — or nothing if no token.
CURL_AUTH=()
if [[ -n "$GITHUB_TOKEN" ]]; then
  CURL_AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  info "Auth         : token loaded from $CONFIG_FILE ✓"
else
  warn "No GITHUB_TOKEN in $CONFIG_FILE — will only work with public repos."
fi

printf '\n%s╔═══════════════════════════════════════╗%s\n' "$BLD" "$RST"
printf '%s║       KrdOS Self-Update System        ║%s\n' "$BLD" "$RST"
printf '%s╚═══════════════════════════════════════╝%s\n\n' "$BLD" "$RST"

# ── Read current installed version ───────────────────────────────────────────
CURRENT_VERSION="none"
if [[ -f "$VERSION_FILE" ]]; then
  CURRENT_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
fi
info "Current version : ${BLD}${CURRENT_VERSION}${RST}"
info "Repository      : ${GITHUB_REPO}"

# ── Fetch latest release info from GitHub API ─────────────────────────────────
info "Checking GitHub for latest release..."
API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

RELEASE_JSON=$(curl -fsSL --max-time 15 \
  "${CURL_AUTH[@]}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_URL" 2>/dev/null)

if [[ -z "$RELEASE_JSON" ]]; then
  die "Could not reach GitHub API at: $API_URL\n  Check internet connection and GITHUB_TOKEN."
fi

# Check for API error response
API_MSG=$(echo "$RELEASE_JSON" | grep -oP '"message":\s*"\K[^"]+' | head -1)
if [[ -n "$API_MSG" ]]; then
  case "$API_MSG" in
    "Not Found")
      die "Repository or release not found: $GITHUB_REPO\n  Check GITHUB_REPO and that at least one release exists." ;;
    "Bad credentials")
      die "GitHub token rejected (Bad credentials).\n  Regenerate your token and update $CONFIG_FILE." ;;
    *)
      die "GitHub API error: $API_MSG" ;;
  esac
fi

REMOTE_VERSION=$(echo "$RELEASE_JSON" | grep -oP '"name":\s*"\K[^"]+' | head -1)
BUNDLE_URL=$(echo "$RELEASE_JSON" \
  | grep -oP '"browser_download_url":\s*"\K[^"]+' \
  | grep "${ASSET_NAME}$" | head -1)
CHECKSUM_URL=$(echo "$RELEASE_JSON" \
  | grep -oP '"browser_download_url":\s*"\K[^"]+' \
  | grep "${CHECKSUM_NAME}$" | head -1)
SETUP_URL=$(echo "$RELEASE_JSON" \
  | grep -oP '"browser_download_url":\s*"\K[^"]+' \
  | grep "setup\.sh$" | head -1)

if [[ -z "$BUNDLE_URL" ]]; then
  die "No '${ASSET_NAME}' asset found in the latest release.\n  Has a GitHub Actions build been published yet?"
fi

info "Latest version  : ${BLD}${REMOTE_VERSION}${RST}"

# ── Version comparison ────────────────────────────────────────────────────────
if [[ "$CURRENT_VERSION" == "$REMOTE_VERSION" && "$FORCE" -eq 0 ]]; then
  ok "Already on the latest version (${CURRENT_VERSION}). Use --force to reinstall."
  exit 0
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  printf '\n  Update available: %s%s%s -> %s%s%s\n' \
    "$YLW" "$CURRENT_VERSION" "$RST" "$GRN" "$REMOTE_VERSION" "$RST"
  printf '  Run %skrdos-update%s to install.\n' "$BLD" "$RST"
  exit 0
fi

# ── Guard: warn if running from inside the Flutter UI terminal ────────────────
# krdos-update stops krdos-ui.service, which kills Flutter and this terminal.
# That is NORMAL — Flutter restarts automatically. But if you need to watch the
# log, open a second TTY first (press Ctrl+Alt+F2, log in as root, run there).
if [[ -n "${KRDOS_SHELL:-}" ]]; then
  printf '\n%s[WARNING]%s Running krdos-update from inside the KrdOS terminal.\n' "$YLW" "$RST"
  printf '  The screen will go BLACK for ~10 seconds while the service restarts.\n'
  printf '  That is normal — Flutter will relaunch automatically.\n'
  printf '  To watch the full log: open a second TTY with Ctrl+Alt+F2.\n\n'
fi

# ── Interactive confirmation (skip when piped / called from Flutter) ──────────
if [[ -t 0 && "$FORCE" -eq 0 ]]; then
  printf '\n  %s%s%s  ->  %s%s%s\n' "$YLW" "$CURRENT_VERSION" "$RST" "$GRN" "$REMOTE_VERSION" "$RST"
  read -r -p "  Apply update now? [Y/n] " REPLY
  REPLY="${REPLY:-Y}"
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    info "Update cancelled."
    exit 0
  fi
fi

# ── Download assets ───────────────────────────────────────────────────────────
mkdir -p "$TMP_DIR"

# Download the main bundle
# -L follows the redirect GitHub issues for asset downloads.
# Private repo assets require the auth header even on the redirect target.
info "Downloading bundle..."
curl -fSL --max-time 300 --progress-bar \
  "${CURL_AUTH[@]}" \
  -H "Accept: application/octet-stream" \
  -o "$TMP_DIR/${ASSET_NAME}" \
  "$BUNDLE_URL" \
  || die "Bundle download failed."

# Download checksum file
if [[ -n "$CHECKSUM_URL" ]]; then
  info "Downloading checksum..."
  curl -fsSL --max-time 30 \
    "${CURL_AUTH[@]}" \
    -H "Accept: application/octet-stream" \
    -o "$TMP_DIR/${CHECKSUM_NAME}" \
    "$CHECKSUM_URL" \
    || warn "Could not download checksum file — skipping verification."
fi

# Verify integrity before touching anything on disk
if [[ -f "$TMP_DIR/${CHECKSUM_NAME}" ]]; then
  info "Verifying SHA-256 checksum..."
  EXPECTED=$(awk '{print $1}' "$TMP_DIR/${CHECKSUM_NAME}")
  ACTUAL=$(sha256sum "$TMP_DIR/${ASSET_NAME}" | awk '{print $1}')
  if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    die "Checksum mismatch — download is corrupt or tampered.\n  Expected : $EXPECTED\n  Got      : $ACTUAL"
  fi
  ok "Checksum verified."
else
  warn "No checksum file — skipping integrity check."
fi

# Download setup.sh (updates services/config alongside the binary)
if [[ -n "$SETUP_URL" ]]; then
  info "Downloading setup.sh..."
  curl -fsSL --max-time 60 \
    "${CURL_AUTH[@]}" \
    -H "Accept: application/octet-stream" \
    -o "$TMP_DIR/setup.sh" \
    "$SETUP_URL" \
    || warn "Could not download setup.sh — skipping service config update."
fi

# ── Extract ───────────────────────────────────────────────────────────────────
info "Extracting bundle..."
tar -xzf "$TMP_DIR/${ASSET_NAME}" -C "$TMP_DIR/" \
  || die "Failed to extract bundle — archive may be corrupt."

BUNDLE_DIR="$TMP_DIR/bundle"
[[ -d "$BUNDLE_DIR" ]]   || die "Expected 'bundle/' directory not found in archive."
[[ -f "$BUNDLE_DIR/krdos" ]] || die "Binary 'krdos' not found inside extracted bundle."

# ── Backup current installation ───────────────────────────────────────────────
BACKUP_DIR="/opt/customos-backup-$(date +%Y%m%d-%H%M%S)"
if [[ -d "$INSTALL_DIR" ]]; then
  info "Backing up current installation → $BACKUP_DIR ..."
  cp -a "$INSTALL_DIR" "$BACKUP_DIR" \
    && ok "Backup: $BACKUP_DIR" \
    || warn "Backup failed — continuing anyway (no rollback available)."
fi

# ── Stop service ──────────────────────────────────────────────────────────────
info "Stopping krdos-ui service..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sleep 1
pkill -f "$INSTALL_DIR/krdos" 2>/dev/null || true
sleep 1

# ── Install ───────────────────────────────────────────────────────────────────
info "Installing to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

if command -v rsync &>/dev/null; then
  rsync -a --delete "$BUNDLE_DIR/" "$INSTALL_DIR/" || die "rsync failed."
else
  cp -a "$BUNDLE_DIR/." "$INSTALL_DIR/"            || die "Copy failed."
fi
chmod +x "$INSTALL_DIR/krdos"

# Register the new shared libs (.so files) with the dynamic linker.
# The launcher script sets LD_LIBRARY_PATH too, but ldconfig makes the
# libs available system-wide and avoids any stale linker cache issues.
if [[ -d "$INSTALL_DIR/lib" ]]; then
  echo "$INSTALL_DIR/lib" > /etc/ld.so.conf.d/krdos-flutter.conf
  ldconfig
  ok "Shared libs registered: $INSTALL_DIR/lib"
fi

ok "Bundle installed."

# Run setup.sh from release (updates systemd services, scripts, conf files).
# This also regenerates /usr/local/bin/krdos-ui pointing to $INSTALL_DIR.
if [[ -f "$TMP_DIR/setup.sh" ]]; then
  info "Running setup.sh from release (service/config update)..."
  chmod +x "$TMP_DIR/setup.sh"
  bash "$TMP_DIR/setup.sh" --update-only 2>&1 | sed 's/^/    /' \
    || warn "setup.sh reported errors — continuing."
  # Re-preserve the update.conf file (setup.sh must not overwrite it)
  [[ -f "$CONFIG_FILE" ]] || warn "setup.sh removed $CONFIG_FILE — please recreate it."
fi

# ── Stamp new version ─────────────────────────────────────────────────────────
mkdir -p /opt/krdos
echo "$REMOTE_VERSION" > "$VERSION_FILE"
ok "Version: $REMOTE_VERSION"

# ── Prune old backups — keep the 3 most recent ───────────────────────────────
ls -dt /opt/customos-backup-* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null || true

# ── Restart service ───────────────────────────────────────────────────────────
info "Starting krdos-ui service..."
systemctl start "$SERVICE_NAME" \
  && ok "krdos-ui restarted — running new version." \
  || {
    err "Service failed to start. Attempting rollback..."
    if [[ -d "$BACKUP_DIR" ]]; then
      cp -a "$BACKUP_DIR/." "$INSTALL_DIR/"
      echo "$CURRENT_VERSION" > "$VERSION_FILE"
      systemctl start "$SERVICE_NAME" \
        && warn "Rolled back to $CURRENT_VERSION." \
        || err "Rollback also failed. Debug with: journalctl -u krdos-ui -n 50"
    fi
    exit 1
  }

printf '\n%s╔═══════════════════════════════════════╗%s\n' "$GRN" "$RST"
printf '%s║   KrdOS updated successfully!         ║%s\n' "$GRN" "$RST"
printf '%s║   %-37s║%s\n' "$GRN" "${REMOTE_VERSION:0:37}" "$RST"
printf '%s╚═══════════════════════════════════════╝%s\n\n' "$GRN" "$RST"
