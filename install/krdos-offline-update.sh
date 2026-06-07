#!/bin/bash
# =============================================================================
# KrdOS Offline Update — run this from a USB drive when there is no internet.
# =============================================================================
#
# HOW TO USE:
#   1. Download from https://github.com/escscripts/krdos/releases/latest :
#        krdos-bundle.tar.gz
#        krdos-update.sh
#        krdos-offline-update.sh  (this file)
#   2. Copy all three to a USB drive (FAT32 or exFAT).
#   3. Boot KrdOS fully (wait for the desktop), then press Ctrl+Alt+F2
#      for a real TTY root shell, OR use the KrdOS terminal app.
#   4. Mount USB and run:
#        mkdir -p /mnt/usb
#        mount /dev/sdb1 /mnt/usb     <- check correct device with: lsblk
#        bash /mnt/usb/krdos-offline-update.sh
#
#   To skip the "Install now?" prompt (needed in Flutter terminal):
#        bash /mnt/usb/krdos-offline-update.sh --yes
#
#   NOTE: Do NOT run this from the initramfs (early boot shell).
#         Boot fully into the KrdOS desktop first.
# =============================================================================

# No 'set -e' — we handle errors manually so the script never silently exits
# mid-install due to a non-fatal issue (e.g. a non-TTY 'read').

RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'; CYN='\033[1;36m'; RST='\033[0m'
ok()   { echo -e "${GRN}  ✓  $*${RST}"; }
warn() { echo -e "${YLW}  ⚠  $*${RST}"; }
err()  { echo -e "${RED}  ✗  $*${RST}"; }
die()  { err "$*"; exit 1; }
info() { echo -e "    →  $*"; }

# ── Parse flags ───────────────────────────────────────────────────────────────
YES=0
FORCE=0
for _arg in "$@"; do
  case "$_arg" in
    --yes|-y)    YES=1 ;;
    --force|-f)  FORCE=1 ;;
  esac
done

# Auto-yes when not running in a real TTY (Flutter terminal, piped, etc.)
[[ ! -t 0 ]] && YES=1

[[ $EUID -ne 0 ]] && die "Run as root: sudo bash $0"

# ── Check we're NOT in initramfs (root-fs read-only) ─────────────────────────
if ! touch /tmp/.krdos_rw_test 2>/dev/null; then
  echo ""
  echo -e "${RED}  ERROR: The root filesystem is read-only.${RST}"
  echo ""
  echo "  You are likely in the initramfs (early boot environment)."
  echo "  This script must run on a fully-booted KrdOS system."
  echo ""
  echo "  Fix options:"
  echo "   A) Let the system finish booting, then run this script from"
  echo "      a real TTY: press Ctrl+Alt+F2 after the desktop appears."
  echo "   B) If you need to remount now:"
  echo "        mount -o remount,rw /"
  echo "      then re-run this script."
  exit 1
fi
rm -f /tmp/.krdos_rw_test 2>/dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="$SCRIPT_DIR/krdos-bundle.tar.gz"
INSTALL_DIR="/opt/customos"
VERSION_FILE="/opt/krdos/version"
SERVICE_NAME="krdos-ui"

# Use /run as temp dir — it's a tmpfs that's ALWAYS writable (even if /tmp
# somehow isn't). Fall back to /opt if /run also fails.
if TMP_DIR=$(mktemp -d /run/krdos-offline-XXXXXX 2>/dev/null); then
  : # /run worked
elif TMP_DIR=$(mktemp -d /tmp/krdos-offline-XXXXXX 2>/dev/null); then
  : # /tmp worked
else
  # Last resort: create a directory directly in /opt
  TMP_DIR="/opt/krdos-offline-tmp-$$"
  mkdir -p "$TMP_DIR" || die "Cannot create temp directory anywhere. Is the root filesystem read-only? Try: mount -o remount,rw /"
fi

cleanup() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT

echo ""
echo -e "${CYN}╔══════════════════════════════════════════════╗${RST}"
echo -e "${CYN}║     KrdOS Offline Update Installer           ║${RST}"
echo -e "${CYN}╚══════════════════════════════════════════════╝${RST}"
echo ""

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ -f "$BUNDLE" ]] || die "Bundle not found: $BUNDLE
  → Download krdos-bundle.tar.gz from:
    https://github.com/escscripts/krdos/releases/latest
  → Place it in the same directory as this script on the USB drive."

info "Bundle     : $BUNDLE"
info "Install to : $INSTALL_DIR"
info "Temp dir   : $TMP_DIR"

# ── Show what's currently installed ───────────────────────────────────────────
CURRENT="(none)"
[[ -f "$VERSION_FILE" ]] && CURRENT=$(cat "$VERSION_FILE" | tr -d '[:space:]')
info "Current version : $CURRENT"

# ── Extract bundle ────────────────────────────────────────────────────────────
info "Extracting bundle..."
tar -xzf "$BUNDLE" -C "$TMP_DIR/" || die "Failed to extract bundle — file may be corrupt or USB read failed."

BUNDLE_DIR="$TMP_DIR/bundle"
[[ -d "$BUNDLE_DIR" ]]       || die "No 'bundle/' directory inside archive."
[[ -f "$BUNDLE_DIR/krdos" ]] || die "No 'krdos' binary inside bundle."

NEW_VERSION="unknown"
[[ -f "$BUNDLE_DIR/version" ]] && NEW_VERSION=$(cat "$BUNDLE_DIR/version" | tr -d '[:space:]')
info "New version     : $NEW_VERSION"

# ── Version check ────────────────────────────────────────────────────────────
if [[ "$CURRENT" == "$NEW_VERSION" && "$FORCE" -eq 0 ]]; then
  echo ""
  warn "Already on version $CURRENT."
  warn "Use --force to reinstall anyway."
  exit 0
fi

# ── Confirm ───────────────────────────────────────────────────────────────────
echo ""
if [[ "$YES" -eq 0 ]]; then
  read -r -p "  Install $NEW_VERSION now? [Y/n] " REPLY || REPLY="Y"
  REPLY="${REPLY:-Y}"
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    info "Cancelled."
    exit 0
  fi
else
  info "Auto-confirmed (--yes or non-interactive mode)."
fi

# ── Install krdos-update.sh from USB ─────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/krdos-update.sh" ]]; then
  cp "$SCRIPT_DIR/krdos-update.sh" /usr/local/bin/krdos-update
  chmod +x /usr/local/bin/krdos-update
  ok "krdos-update installed from USB"
else
  warn "krdos-update.sh not on USB — existing /usr/local/bin/krdos-update kept."
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
  info "Backing up → $BACKUP ..."
  cp -a "$INSTALL_DIR" "$BACKUP" \
    && ok "Backup: $BACKUP" \
    || warn "Backup failed — continuing without backup."
fi

# ── Install new bundle ────────────────────────────────────────────────────────
info "Installing to $INSTALL_DIR ..."
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

# ── Prune old backups (keep 3 most recent) ────────────────────────────────────
ls -dt /opt/customos-backup-* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null || true

# ── Rewrite launcher to guarantee correct path ───────────────────────────────
# This fixes the "update seems to work but nothing changes" issue where the
# launcher was pointing to a different directory.
cat > /usr/local/bin/krdos-ui <<WRAPPER
#!/bin/bash
export HOME=/root
export DISPLAY=\${DISPLAY:-:0}
export XDG_RUNTIME_DIR=/run/user/0
export KRDOS_SHELL=1
export GDK_BACKEND=x11
export CLUTTER_BACKEND=x11
export XCURSOR_THEME=DMZ-White
export XCURSOR_SIZE=24
export FONTCONFIG_PATH=/etc/fonts
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib:\$LD_LIBRARY_PATH"
cd "${INSTALL_DIR}"
exec "${INSTALL_DIR}/krdos" "\$@"
WRAPPER
chmod +x /usr/local/bin/krdos-ui
ok "Launcher /usr/local/bin/krdos-ui → $INSTALL_DIR"

# ── Also fix WiFi while we're here ────────────────────────────────────────────
info "Unblocking WiFi radio..."
rfkill unblock all 2>/dev/null || true
systemctl start NetworkManager 2>/dev/null || true
sleep 1
nmcli radio wifi on 2>/dev/null || true
ok "WiFi radio unblocked."

# ── Restart UI ────────────────────────────────────────────────────────────────
info "Restarting krdos-ui service..."
if systemctl start "$SERVICE_NAME" 2>/dev/null; then
  ok "krdos-ui started — running $NEW_VERSION."
else
  warn "Service start failed. Try manually: systemctl restart krdos-ui"
  warn "Logs: journalctl -u krdos-ui -n 50"
fi

echo ""
echo -e "${GRN}╔══════════════════════════════════════════════╗${RST}"
echo -e "${GRN}║   KrdOS updated successfully!                ║${RST}"
echo -e "${GRN}║   Version: ${NEW_VERSION:0:34}  ║${RST}"
echo -e "${GRN}╚══════════════════════════════════════════════╝${RST}"
echo ""
echo "  UI should appear on screen in a few seconds."
echo "  If it does not: systemctl restart krdos-ui"
echo ""
echo "  Connect to WiFi:"
echo "    nmcli dev wifi list"
echo "    nmcli dev wifi connect \"SSID\" password \"yourpassword\""
echo ""
