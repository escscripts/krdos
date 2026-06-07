#!/bin/bash
# =============================================================================
# KrdOS Offline Update — run this from a USB drive when there is no internet.
# =============================================================================
#
# HOW TO USE (from a Windows machine):
#   1. Go to https://github.com/escscripts/krdos/releases/latest
#   2. Download:  krdos-bundle.tar.gz
#                 krdos-update.sh        (optional but recommended)
#   3. Copy those files + THIS script to a FAT32/exFAT USB drive.
#   4. On the KrdOS machine open a root terminal and run:
#
#        bash /path/to/krdos-offline-update.sh
#
#      The script detects its own location, finds the bundle next to it,
#      installs it to /opt/customos/, and restarts the UI.
#
# =============================================================================

set -euo pipefail

RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'; CYN='\033[1;36m'; RST='\033[0m'
ok()   { echo -e "${GRN}  ✓  $*${RST}"; }
warn() { echo -e "${YLW}  ⚠  $*${RST}"; }
err()  { echo -e "${RED}  ✗  $*${RST}"; }
die()  { err "$*"; exit 1; }
info() { echo -e "    →  $*"; }

[[ $EUID -ne 0 ]] && die "Run as root: sudo bash $0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="$SCRIPT_DIR/krdos-bundle.tar.gz"
INSTALL_DIR="/opt/customos"
VERSION_FILE="/opt/krdos/version"
SERVICE_NAME="krdos-ui"
TMP_DIR=$(mktemp -d /tmp/krdos-offline-XXXXXX)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo ""
echo -e "${CYN}╔══════════════════════════════════════════════╗${RST}"
echo -e "${CYN}║     KrdOS Offline Update Installer           ║${RST}"
echo -e "${CYN}╚══════════════════════════════════════════════╝${RST}"
echo ""

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ -f "$BUNDLE" ]] || die "Bundle not found: $BUNDLE\n  Download krdos-bundle.tar.gz from https://github.com/escscripts/krdos/releases/latest and place it next to this script."

info "Bundle     : $BUNDLE"
info "Install to : $INSTALL_DIR"

# ── Show what's currently installed ───────────────────────────────────────────
CURRENT="(none)"
[[ -f "$VERSION_FILE" ]] && CURRENT=$(cat "$VERSION_FILE" | tr -d '[:space:]')
info "Current version : $CURRENT"

# ── Verify bundle has a version stamp ─────────────────────────────────────────
info "Extracting bundle..."
tar -xzf "$BUNDLE" -C "$TMP_DIR/" || die "Failed to extract bundle — file may be corrupt."

BUNDLE_DIR="$TMP_DIR/bundle"
[[ -d "$BUNDLE_DIR" ]]      || die "No 'bundle/' directory inside archive."
[[ -f "$BUNDLE_DIR/krdos" ]] || die "No 'krdos' binary inside bundle."

NEW_VERSION="unknown"
[[ -f "$BUNDLE_DIR/version" ]] && NEW_VERSION=$(cat "$BUNDLE_DIR/version" | tr -d '[:space:]')
info "New version     : $NEW_VERSION"

if [[ "$CURRENT" == "$NEW_VERSION" ]]; then
  echo ""
  warn "Already on version $CURRENT. Use --force to reinstall anyway."
  [[ "${1:-}" == "--force" ]] || exit 0
fi

echo ""
read -r -p "  Install $NEW_VERSION now? [Y/n] " REPLY
REPLY="${REPLY:-Y}"
[[ "$REPLY" =~ ^[Yy]$ ]] || { info "Cancelled."; exit 0; }

# ── Install krdos-update.sh if present on USB ─────────────────────────────────
if [[ -f "$SCRIPT_DIR/krdos-update.sh" ]]; then
  cp "$SCRIPT_DIR/krdos-update.sh" /usr/local/bin/krdos-update
  chmod +x /usr/local/bin/krdos-update
  ok "krdos-update installed from USB"
else
  warn "krdos-update.sh not found next to this script — skipping (existing script kept)."
  info "To get it: download krdos-update.sh from https://github.com/escscripts/krdos/releases/latest"
fi

# ── Stop the running UI ───────────────────────────────────────────────────────
info "Stopping krdos-ui service..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sleep 1
pkill -f "$INSTALL_DIR/krdos" 2>/dev/null || true
sleep 1

# ── Backup current install ────────────────────────────────────────────────────
if [[ -d "$INSTALL_DIR" ]]; then
  BACKUP="/opt/customos-backup-$(date +%Y%m%d-%H%M%S)"
  info "Backing up current install → $BACKUP"
  cp -a "$INSTALL_DIR" "$BACKUP" && ok "Backup done: $BACKUP" || warn "Backup failed — continuing."
fi

# ── Install new bundle ────────────────────────────────────────────────────────
info "Installing new bundle to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
if command -v rsync &>/dev/null; then
  rsync -a --delete "$BUNDLE_DIR/" "$INSTALL_DIR/" || die "rsync failed."
else
  cp -a "$BUNDLE_DIR/." "$INSTALL_DIR/"            || die "Copy failed."
fi
chmod +x "$INSTALL_DIR/krdos"
ok "Bundle installed."

# ── Register shared libs ──────────────────────────────────────────────────────
if [[ -d "$INSTALL_DIR/lib" ]]; then
  echo "$INSTALL_DIR/lib" > /etc/ld.so.conf.d/krdos-flutter.conf
  ldconfig
  ok "Shared libs registered."
fi

# ── Stamp version ─────────────────────────────────────────────────────────────
mkdir -p /opt/krdos
echo "$NEW_VERSION" > "$VERSION_FILE"
ok "Version stamped: $NEW_VERSION"

# ── Prune old backups (keep 3) ────────────────────────────────────────────────
ls -dt /opt/customos-backup-* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null || true

# ── Make sure the launcher points to the right place ─────────────────────────
# Re-write /usr/local/bin/krdos-ui so it always points to $INSTALL_DIR
cat > /usr/local/bin/krdos-ui <<WRAPPER
#!/bin/bash
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib:\$LD_LIBRARY_PATH"
cd "${INSTALL_DIR}"
exec "${INSTALL_DIR}/krdos" "\$@"
WRAPPER
chmod +x /usr/local/bin/krdos-ui
ok "Launcher /usr/local/bin/krdos-ui updated → $INSTALL_DIR"

# ── Restart UI ────────────────────────────────────────────────────────────────
info "Starting krdos-ui service..."
systemctl start "$SERVICE_NAME" \
  && ok "krdos-ui restarted — running new version $NEW_VERSION." \
  || {
    err "Service failed to start."
    err "Check logs: journalctl -u krdos-ui -n 50"
    exit 1
  }

echo ""
echo -e "${GRN}╔══════════════════════════════════════════════╗${RST}"
echo -e "${GRN}║   KrdOS updated successfully!                ║${RST}"
echo -e "${GRN}║   ${NEW_VERSION:0:42}  ║${RST}"
echo -e "${GRN}╚══════════════════════════════════════════════╝${RST}"
echo ""
echo "  The UI should restart on screen in a few seconds."
echo "  If it doesn't, run:  systemctl restart krdos-ui"
echo ""

# ── Also fix WiFi while we're here ────────────────────────────────────────────
info "Ensuring WiFi is active..."
rfkill unblock all 2>/dev/null || true
systemctl start NetworkManager 2>/dev/null || true
nmcli radio wifi on 2>/dev/null || true
ok "WiFi radio unblocked."
echo ""
echo "  To connect to WiFi from a terminal:"
echo "    nmcli dev wifi list"
echo "    nmcli dev wifi connect \"SSID\" password \"yourpassword\""
echo ""
