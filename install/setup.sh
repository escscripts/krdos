#!/usr/bin/env bash
# =============================================================================
# KrdOS Post-Install Setup  v2.0
# =============================================================================
# Run ONCE as root inside KrdOS after first boot:
#     sudo bash setup.sh
#
# Works on ANY hardware — laptops, desktops, 1 screen or 4.
# Resolution is detected at runtime; nothing is hard-coded.
# =============================================================================

RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'; CYN='\033[1;36m'; RST='\033[0m'
step() {
  echo -e "\n${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
  echo -e "${CYN}  STEP $1  —  $2${RST}"
  echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
}
ok()   { echo -e "${GRN}  ✓  $*${RST}"; }
warn() { echo -e "${YLW}  ⚠  $*${RST}"; }
err()  { echo -e "${RED}  ✗  $*  (continuing)${RST}"; }
info() { echo -e "    →  $*"; }

[[ $EUID -ne 0 ]] && { echo -e "${RED}Run as root: sudo bash setup.sh${RST}"; exit 1; }

echo ""
echo -e "${CYN}  KrdOS Setup v2.0${RST}"
echo    "  Installs X11, display management, networking, Bluetooth, audio, browser."
echo    "  Works on any hardware. System will reboot when complete."
echo ""
read -r -p "  Press ENTER to start (Ctrl+C to cancel): "

# =============================================================================
# STEP 1 — Kali rolling repositories
# =============================================================================
step "1/9" "Add Kali rolling repositories"

# Install kali-archive-keyring so apt trusts the repo
if ! dpkg -l kali-archive-keyring &>/dev/null; then
  info "Downloading Kali keyring…"
  TMP_DEB="/tmp/kali-keyring.deb"
  curl -fsSL "https://http.kali.org/kali/pool/main/k/kali-archive-keyring/kali-archive-keyring_2024.1_all.deb" \
    -o "$TMP_DEB" 2>/dev/null \
    || wget -q "https://http.kali.org/kali/pool/main/k/kali-archive-keyring/kali-archive-keyring_2024.1_all.deb" \
       -O "$TMP_DEB" 2>/dev/null \
    || warn "Could not download Kali keyring — using trusted=yes fallback"
  [[ -s "$TMP_DEB" ]] && dpkg -i "$TMP_DEB" && ok "Kali keyring installed" || true
  rm -f "$TMP_DEB"
fi

cat > /etc/apt/sources.list <<'SOURCES'
# Debian bookworm — stable base
deb http://deb.debian.org/debian               bookworm          main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian               bookworm-updates  main contrib non-free non-free-firmware

# Kali rolling — tools, Firefox, Kali-specific packages
deb [trusted=yes] http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
SOURCES

apt-get update -y -qq 2>&1 | tail -2 \
  && ok "apt-get update OK" \
  || warn "apt-get update had errors"

DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq 2>/dev/null \
  && ok "System upgraded" || warn "Upgrade had errors"

# =============================================================================
# STEP 2 — Install all packages
# =============================================================================
step "2/9" "Install X11, WM, Flutter libs, networking, Bluetooth, audio, browser"

pkg() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" \
    2>&1 | grep -E "^(Err:|E:)" || true
}

# X11 display server
pkg \
  xserver-xorg xserver-xorg-core \
  xserver-xorg-input-all xserver-xorg-video-all \
  xinit x11-xserver-utils x11-utils x11-common \
  xauth libx11-6 libxext6
ok "Xorg installed"

# Window manager + kiosk tools
pkg \
  matchbox-window-manager \
  wmctrl \
  xdotool \
  unclutter \
  xterm
ok "Window manager tools installed"

# Cursor themes — DMZ-White is the clean neutral pointer used on most distros
pkg \
  dmz-cursor-theme \
  vanilla-dmz \
  libxcursor1 \
  xcursor-themes
ok "Cursor themes installed (DMZ-White)"

# Flutter / GTK3 runtime
pkg \
  libgtk-3-0 libgtk-3-bin \
  libglib2.0-0 libgdk-pixbuf-2.0-0 \
  libpango-1.0-0 libpangocairo-1.0-0 \
  libcairo2 libatk1.0-0 libatk-bridge2.0-0 \
  libxrender1 libxtst6 libxi6 \
  libxcomposite1 libxcursor1 libxdamage1 \
  libxfixes3 libxinerama1 libxrandr2 libxss1 \
  libgl1-mesa-dri libgl1-mesa-glx \
  libgles2 libepoxy0 libegl1 libdrm2 libgbm1 \
  libstdc++6 libgcc-s1 libc6 \
  libfontconfig1 libfreetype6 libharfbuzz0b \
  fonts-noto-core fonts-noto-color-emoji fonts-dejavu-core \
  fonts-liberation fonts-liberation2 \
  fontconfig
ok "Flutter/GTK runtime libraries installed"

# Rebuild font cache so every app (including Flutter) picks up new fonts
fc-cache -f 2>/dev/null || true
ok "Font cache rebuilt"

# WiFi + networking (firmware covers Intel/Realtek/Atheros/Broadcom/MediaTek)
pkg \
  network-manager wpasupplicant \
  wireless-tools iw rfkill \
  firmware-linux-nonfree firmware-iwlwifi \
  firmware-realtek firmware-atheros \
  firmware-brcm80211 firmware-misc-nonfree \
  iproute2 iputils-ping net-tools curl wget ca-certificates
ok "Networking + WiFi firmware installed"

# Bluetooth
pkg bluez bluez-tools bluetooth libbluetooth3
ok "Bluetooth installed"

# Audio
pkg \
  pulseaudio pulseaudio-module-bluetooth \
  pulseaudio-utils alsa-utils alsa-base libasound2 libpulse0
ok "Audio installed"

# Browser + utilities
pkg \
  firefox-esr \
  htop procps kmod usbutils pciutils lsof rsync sudo util-linux \
  dbus dbus-x11 policykit-1
ok "Firefox + utilities installed"

# USB auto-mount (udisks2 handles plugging/unplugging, udiskie does tray)
pkg udisks2 udiskie
ok "USB auto-mount tools installed"

# Brightness control (works via sysfs, supports most laptops)
pkg brightnessctl
# Allow root and krdos user to control brightness without sudo
echo 'SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chgrp -R video /sys%p", RUN+="/bin/chmod -R g+w /sys%p"' \
  > /etc/udev/rules.d/90-backlight.rules
ok "Brightness control installed"

# Network / BT / audio GUI helpers (optional, used for troubleshooting)
pkg network-manager-gnome blueman pavucontrol 2>/dev/null || true
ok "GUI network/BT/audio helpers installed (optional)"

# arandr (graphical xrandr front-end)
pkg arandr 2>/dev/null || true
ok "arandr installed (optional)"

# Allow Xorg to run as root
mkdir -p /etc/X11
cat > /etc/X11/Xwrapper.config <<'XWRAP'
allowed_users=anybody
needs_root_rights=yes
XWRAP
ok "Xorg wrapper: root access enabled"

# ── Cursor theme: system default = DMZ-White ─────────────────────────────────
# /usr/share/icons/default/index.theme tells every GTK/X11 app which theme to use
mkdir -p /usr/share/icons/default
cat > /usr/share/icons/default/index.theme <<'ICONTHEME'
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=DMZ-White
ICONTHEME
ok "Icon theme index written: Inherits=DMZ-White"

# GTK-3 settings for root (cursor theme + fallback font)
mkdir -p /root/.config/gtk-3.0
cat > /root/.config/gtk-3.0/settings.ini <<'GTK3'
[Settings]
gtk-cursor-theme-name=DMZ-White
gtk-cursor-theme-size=24
gtk-font-name=Noto Sans 11
GTK3

# GTK-2 settings (some apps still read this)
cat > /root/.gtkrc-2.0 <<'GTK2'
gtk-cursor-theme-name="DMZ-White"
gtk-cursor-theme-size=24
gtk-font-name="Noto Sans 11"
GTK2

# Xresources — loaded in xinitrc via xrdb; tells Xlib apps which cursor to use
cat > /root/.Xresources <<'XRESOURCES'
Xcursor.theme: DMZ-White
Xcursor.size:  24
XRESOURCES
ok "GTK + Xresources cursor settings written"

# =============================================================================
# STEP 3 — Detect Flutter binary and create launcher wrapper
# =============================================================================
step "3/9" "Detect Flutter binary and create /usr/local/bin/krdos-ui"

FLUTTER_APP=""
FLUTTER_DIR=""
for candidate in \
    /opt/customos/krdos \
    /opt/krdos/custom_os_ui \
    /opt/krdos/krdos \
    /opt/customos/custom_os_ui; do
  if [[ -f "$candidate" ]]; then
    chmod +x "$candidate"
    FLUTTER_APP="$candidate"
    FLUTTER_DIR="$(dirname "$candidate")"
    ok "Flutter binary: $FLUTTER_APP"
    break
  fi
done

if [[ -z "$FLUTTER_APP" ]]; then
  warn "Flutter binary not found — paths checked:"
  warn "  /opt/customos/krdos  /opt/krdos/custom_os_ui"
  warn "Copy the Flutter bundle to /opt/customos/ then re-run setup.sh"
  FLUTTER_APP="/opt/customos/krdos"
  FLUTTER_DIR="/opt/customos"
fi

# Register Flutter's bundled .so files system-wide
if [[ -d "$FLUTTER_DIR/lib" ]]; then
  echo "$FLUTTER_DIR/lib" > /etc/ld.so.conf.d/krdos-flutter.conf
  ldconfig
  ok "Flutter lib path registered: $FLUTTER_DIR/lib"
fi

# Canonical launcher — called from xinitrc
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
export LD_LIBRARY_PATH="$FLUTTER_DIR/lib:\$LD_LIBRARY_PATH"
cd "$FLUTTER_DIR"
exec "$FLUTTER_APP" "\$@"
WRAPPER
chmod +x /usr/local/bin/krdos-ui
ok "Launcher: /usr/local/bin/krdos-ui"

# =============================================================================
# STEP 4 — Display configuration script (works on any hardware)
# =============================================================================
step "4/9" "Create dynamic display configuration script"

cat > /usr/local/bin/krdos-configure-displays.sh <<'DISPSCRIPT'
#!/bin/bash
# =============================================================================
# krdos-configure-displays.sh
# Called from: xinitrc (on X start) and udev (on monitor hotplug)
# Works on any number of monitors with any outputs (eDP, HDMI, DP, VGA, …)
# =============================================================================
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-/root/.Xauthority}"

LOG=/var/log/krdos-display.log
log() { echo "[$(date +%T)] $*" >> "$LOG"; echo "$*"; }

# ── Wait for xrandr to be usable (slow EDID reads on some hardware) ──────────
for i in $(seq 1 10); do
  xrandr --query &>/dev/null && break
  sleep 0.5
done

# ── First pass: let X auto-detect ────────────────────────────────────────────
xrandr --auto

# ── Parse connected outputs ───────────────────────────────────────────────────
# Retry up to 5s for outputs to appear (hot-plug can be slow)
for attempt in $(seq 1 10); do
  mapfile -t CONNECTED < <(xrandr --query 2>/dev/null | awk '/ connected/{print $1}')
  [[ ${#CONNECTED[@]} -gt 0 ]] && break
  sleep 0.5
done

if [[ ${#CONNECTED[@]} -eq 0 ]]; then
  log "No connected outputs detected — leaving xrandr --auto in place"
  exit 0
fi

log "Connected outputs: ${CONNECTED[*]}"

# ── Helper: best mode for an output (first listed = native/preferred) ─────────
best_mode() {
  local out="$1"
  xrandr --query 2>/dev/null | awk -v o="$out" '
    $1==o && /connected/{f=1;next}
    f && /^[[:space:]]+[0-9]+x[0-9]+/{gsub(/^[[:space:]]*/,""); print $1; exit}
    f && /^[A-Za-z0-9]/{f=0}
  '
}

# ── Helper: preferred refresh rate for a mode (marked + or *, else highest) ──
best_rate() {
  local out="$1" mode="$2"
  xrandr --query 2>/dev/null | awk -v o="$out" -v m="$mode" '
    $1==o && /connected/{f=1;next}
    f && $1==m{
      best=0
      for(i=2;i<=NF;i++){
        r=$i; pref=(r ~ /[*+]/)
        gsub(/[*+]/,"",r)
        if(pref && r+0>0){ print r+0; exit }
        if(r+0>best) best=r+0
      }
      print best; exit
    }
    f && /^[A-Za-z0-9]/{f=0}
  '
}

# ── Choose primary display ────────────────────────────────────────────────────
# Prefer internal panel (eDP, LVDS, DSI) — these are built-in laptop/tablet screens
PRIMARY=""
for out in "${CONNECTED[@]}"; do
  if [[ "$out" =~ ^(eDP|LVDS|DSI) ]]; then
    PRIMARY="$out"
    break
  fi
done
# Fall back to first connected output (desktop with external monitor only)
[[ -z "$PRIMARY" ]] && PRIMARY="${CONNECTED[0]}"
log "Primary output: $PRIMARY"

# ── Configure primary display ─────────────────────────────────────────────────
P_MODE=$(best_mode "$PRIMARY")
P_RATE=$(best_rate "$PRIMARY" "$P_MODE")

if [[ -n "$P_MODE" ]]; then
  if [[ -n "$P_RATE" && "$P_RATE" != "0" ]]; then
    xrandr --output "$PRIMARY" --mode "$P_MODE" --rate "$P_RATE" --primary \
      && log "Primary: $PRIMARY → $P_MODE @ ${P_RATE}Hz" \
      || { xrandr --output "$PRIMARY" --mode "$P_MODE" --primary
           log "Primary (no rate): $PRIMARY → $P_MODE"; }
  else
    xrandr --output "$PRIMARY" --mode "$P_MODE" --primary
    log "Primary (auto rate): $PRIMARY → $P_MODE"
  fi
else
  log "No modes found for $PRIMARY — leaving as-is"
fi

# ── Configure secondary displays (extend right of previous) ──────────────────
PREV="$PRIMARY"
for out in "${CONNECTED[@]}"; do
  [[ "$out" == "$PRIMARY" ]] && continue
  S_MODE=$(best_mode "$out")
  S_RATE=$(best_rate "$out" "$S_MODE")
  if [[ -n "$S_MODE" ]]; then
    if [[ -n "$S_RATE" && "$S_RATE" != "0" ]]; then
      xrandr --output "$out" --mode "$S_MODE" --rate "$S_RATE" --right-of "$PREV"
    else
      xrandr --output "$out" --mode "$S_MODE" --right-of "$PREV"
    fi
    log "Secondary: $out → $S_MODE right-of $PREV"
    PREV="$out"
  fi
done

# ── Turn off disconnected outputs ─────────────────────────────────────────────
while read -r disc; do
  xrandr --output "$disc" --off 2>/dev/null
  log "Disabled disconnected output: $disc"
done < <(xrandr --query 2>/dev/null | awk '/ disconnected/{print $1}')

# ── Emit primary screen dimensions to a file Flutter can read ─────────────────
# Format: WIDTH HEIGHT  (e.g. 1920 1080)
mkdir -p /run/krdos
xrandr --query 2>/dev/null | awk '/ connected primary/{
  match($0, /([0-9]+)x([0-9]+)\+[0-9]+\+[0-9]+/, a)
  if(a[1]+0>0) { print a[1], a[2] }
}' > /run/krdos/primary-resolution

cat /run/krdos/primary-resolution | read W H 2>/dev/null
log "Primary resolution: $(cat /run/krdos/primary-resolution)"
DISPSCRIPT
chmod +x /usr/local/bin/krdos-configure-displays.sh
ok "Display config script: /usr/local/bin/krdos-configure-displays.sh"

# =============================================================================
# STEP 5 — xinitrc (X11 session — display + WM + watchdog + Flutter)
# =============================================================================
step "5/9" "Create /etc/krdos/xinitrc"

mkdir -p /etc/krdos

cat > /etc/krdos/xinitrc <<'XINITRC'
#!/bin/bash
# =============================================================================
# KrdOS X11 session
# Start order:
#   1. screensaver/DPMS off
#   2. configure displays (native resolution, all monitors)
#   3. black background + hide cursor
#   4. matchbox WM  (wait until it owns the display)
#   5. PulseAudio
#   6. Flutter UI  + fullscreen watchdog
# =============================================================================
exec &> /var/log/krdos-x11-session.log   # log everything for debugging

# ── Screensaver / DPMS: all off ───────────────────────────────────────────────
xset s off
xset s noblank
xset -dpms
xset r rate 250 30

# ── Configure displays ────────────────────────────────────────────────────────
# Wait for DRM/KMS to settle (important on cold boot)
sleep 1
/usr/local/bin/krdos-configure-displays.sh

# Read primary screen size (set by configure-displays.sh)
read -r SCREEN_W SCREEN_H < /run/krdos/primary-resolution 2>/dev/null
# Fallback: ask X directly
if [[ -z "$SCREEN_W" || "$SCREEN_W" -lt 100 ]]; then
  SCREEN_WH=$(xrandr --query 2>/dev/null \
    | awk '/current/{match($0,/current ([0-9]+) x ([0-9]+)/,a); print a[1],a[2]}')
  SCREEN_W=${SCREEN_WH%% *}
  SCREEN_H=${SCREEN_WH##* }
fi
: "${SCREEN_W:=1920}" "${SCREEN_H:=1080}"
echo "KrdOS: screen ${SCREEN_W}x${SCREEN_H}"

# ── Root window ───────────────────────────────────────────────────────────────
xsetroot -solid black

# ── Cursor theme — MUST be set before any window opens ───────────────────────
# Load Xcursor.theme + Xcursor.size into the X resource database
xrdb -merge /root/.Xresources 2>/dev/null || true
# Set the root-window cursor to the standard left-pointing arrow
xsetroot -cursor_name left_ptr
# Export so every GTK/Xlib child process inherits the theme
export XCURSOR_THEME=DMZ-White
export XCURSOR_SIZE=24
echo "KrdOS: cursor → $XCURSOR_THEME size ${XCURSOR_SIZE}px"

# ── Hide cursor after 3 s idle; moving mouse makes it reappear instantly ──────
unclutter -idle 3 -root &

# ── matchbox WM — forces every window fullscreen ──────────────────────────────
matchbox-window-manager -use_titlebar no &
MATCHBOX_PID=$!

# Wait (max 5 s) for matchbox to register itself as the WM
WM_READY=false
for i in $(seq 1 25); do
  if xprop -root _NET_WM_NAME 2>/dev/null | grep -qi "matchbox"; then
    WM_READY=true; break
  fi
  sleep 0.2
done
echo "KrdOS: matchbox WM ready=$WM_READY"

# ── PulseAudio ────────────────────────────────────────────────────────────────
pulseaudio --start --log-target=syslog 2>/dev/null || true

# ── Launch Flutter UI ─────────────────────────────────────────────────────────
/usr/local/bin/krdos-ui &
FLUTTER_PID=$!
echo "KrdOS: Flutter PID=$FLUTTER_PID"

# ── Fullscreen watchdog ───────────────────────────────────────────────────────
# matchbox should handle fullscreen, but this watchdog is the belt-and-suspenders.
# It waits for Flutter's window to appear, then:
#   a) moves it to 0,0
#   b) resizes it to full screen dimensions
#   c) sets EWMH _NET_WM_STATE_FULLSCREEN via wmctrl
# After initial enforcement it re-checks every 5 s in case of resize events.
(
  WID=""
  # Wait up to 20 s for the Flutter window to appear
  for i in $(seq 1 40); do
    WID=$(xdotool search --pid "$FLUTTER_PID" 2>/dev/null | tail -1)
    [[ -n "$WID" ]] && break
    sleep 0.5
  done

  if [[ -z "$WID" ]]; then
    echo "KrdOS watchdog: Flutter window not found after 20s"
    exit 0
  fi

  echo "KrdOS watchdog: found window $WID — enforcing fullscreen"

  enforce_fullscreen() {
    local wid="$1"
    # Re-read resolution in case of hotplug
    local w h wh
    wh=$(xrandr --query 2>/dev/null \
      | awk '/current/{match($0,/current ([0-9]+) x ([0-9]+)/,a); print a[1],a[2]}')
    w=${wh%% *}; h=${wh##* }
    : "${w:=$SCREEN_W}" "${h:=$SCREEN_H}"

    # Remove decorations, position at 0,0, resize to full screen
    xdotool windowmove --sync "$wid" 0 0               2>/dev/null || true
    xdotool windowsize --sync "$wid" "$w" "$h"         2>/dev/null || true
    # Set EWMH fullscreen state (respected by matchbox and most WMs)
    wmctrl -i -r "$wid" -b add,fullscreen               2>/dev/null || true
    xdotool windowfocus --sync "$wid"                  2>/dev/null || true
    xdotool windowraise "$wid"                          2>/dev/null || true
  }

  # Initial enforcement
  enforce_fullscreen "$WID"
  sleep 1
  enforce_fullscreen "$WID"   # double-tap: catches late resize events

  # Periodic re-enforcement (handles resolution changes after hotplug)
  while kill -0 "$FLUTTER_PID" 2>/dev/null; do
    sleep 5
    # Re-check window still exists
    WID=$(xdotool search --pid "$FLUTTER_PID" 2>/dev/null | tail -1)
    [[ -n "$WID" ]] && enforce_fullscreen "$WID"
  done
) &

# Wait for Flutter — when it exits the whole X session restarts via the service
wait "$FLUTTER_PID"
XINITRC
chmod +x /etc/krdos/xinitrc
ok "X11 session script: /etc/krdos/xinitrc"

# =============================================================================
# STEP 6 — Monitor hot-plug: udev rule + handler
# =============================================================================
step "6/9" "Configure monitor hot-plug detection"

# Script called by udev when DRM state changes (monitor plug/unplug)
cat > /usr/local/bin/krdos-hotplug.sh <<'HOTPLUG'
#!/bin/bash
# Called by udev on DRM hotplug — reconfigures displays in the live X session
export DISPLAY=:0
export XAUTHORITY=/root/.Xauthority

# Small delay so the kernel finishes reading EDID
sleep 1

/usr/local/bin/krdos-configure-displays.sh

# After reconfiguring displays, re-enforce Flutter fullscreen
WID=$(xdotool search --name "" 2>/dev/null | tail -1)
if [[ -n "$WID" ]]; then
  WH=$(xrandr --query 2>/dev/null \
    | awk '/current/{match($0,/current ([0-9]+) x ([0-9]+)/,a); print a[1],a[2]}')
  W=${WH%% *}; H=${WH##* }
  xdotool windowmove "$WID" 0 0 2>/dev/null
  xdotool windowsize "$WID" "$W" "$H" 2>/dev/null
  wmctrl -i -r "$WID" -b add,fullscreen 2>/dev/null
fi
HOTPLUG
chmod +x /usr/local/bin/krdos-hotplug.sh

# udev rule — fires on any DRM (Direct Rendering Manager) change event
cat > /etc/udev/rules.d/95-krdos-display-hotplug.rules <<'UDEV'
# KrdOS: reconfigure displays when a monitor is connected or disconnected
ACTION=="change", SUBSYSTEM=="drm", RUN+="/bin/bash /usr/local/bin/krdos-hotplug.sh"
UDEV

udevadm control --reload-rules 2>/dev/null || true
ok "udev hotplug rule: /etc/udev/rules.d/95-krdos-display-hotplug.rules"

# USB auto-mount udev rule — udisks2 handles mounting; this triggers it
cat > /etc/udev/rules.d/96-krdos-usb-mount.rules <<'USBMOUNT'
# KrdOS: auto-mount USB partitions when plugged in
ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", \
  ENV{ID_BUS}=="usb", \
  RUN+="/usr/bin/udisksctl mount -b /dev/%k --no-user-interaction"
USBMOUNT
udevadm control --reload-rules 2>/dev/null || true
ok "USB auto-mount udev rule: /etc/udev/rules.d/96-krdos-usb-mount.rules"

# =============================================================================
# STEP 7 — krdos-ui.service (owns X11 + Flutter, Restart=always)
# =============================================================================
step "7/9" "Create and enable krdos-ui.service"

# Disable old Weston-based services
for svc in weston krdos; do
  systemctl disable "$svc" 2>/dev/null || true
  systemctl stop    "$svc" 2>/dev/null || true
done
ok "Old Weston services disabled"

cat > /etc/systemd/system/krdos-ui.service <<'SERVICE'
[Unit]
Description=KrdOS Flutter UI (X11)
Documentation=https://krdos.local
# Start after udev has settled (so display outputs are detectable)
After=systemd-udev-settle.service systemd-logind.service dbus.service
Wants=systemd-logind.service dbus.service
# Do NOT start if we're going into rescue/emergency mode
ConditionPathExists=/usr/bin/Xorg

[Service]
Type=simple
User=root

# Set up runtime dirs expected by PulseAudio, D-Bus, and X
ExecStartPre=/bin/mkdir -p /run/user/0
ExecStartPre=/bin/chmod 700 /run/user/0

Environment=HOME=/root
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus
# Cursor theme — inherited by xinit → xinitrc → Flutter
Environment=XCURSOR_THEME=DMZ-White
Environment=XCURSOR_SIZE=24
# Force GTK to use X11 backend (not Wayland) and pick up the cursor theme
Environment=GDK_BACKEND=x11
Environment=FONTCONFIG_PATH=/etc/fonts

# Start X inside a D-Bus session (NetworkManager / BT tray need the bus)
# vt1          = owns Virtual Terminal 1 (no getty prompt ever appears)
# -nolisten tcp = security: no remote X connections
# NOTE: -nocursor is intentionally absent — cursor visibility is controlled
#        by the DMZ-White theme + unclutter in xinitrc, not suppressed here
ExecStart=/usr/bin/dbus-run-session \
  /usr/bin/xinit /etc/krdos/xinitrc \
  -- /usr/bin/X vt1 -nolisten tcp

# Restart on ANY exit — crash, OOM-kill, or explicit exit — so the screen
# never goes blank on a deployed device
Restart=always
RestartSec=3
TimeoutStopSec=10

# Clean up X lock file on exit so next start doesn't fail
ExecStopPost=/bin/rm -f /tmp/.X0-lock /tmp/.X11-unix/X0

[Install]
WantedBy=multi-user.target
SERVICE

# Write initial version file (will be overwritten by krdos-update on first OTA)
mkdir -p /opt/krdos
INITIAL_VERSION="initial-$(date +%Y%m%d)"
[[ -f /opt/krdos/version ]] || echo "$INITIAL_VERSION" > /opt/krdos/version
ok "Version file: $(cat /opt/krdos/version)"

# Mask getty@tty1 — krdos-ui.service owns vt1, login prompt must never appear
systemctl mask getty@tty1 2>/dev/null && ok "getty@tty1 masked" || warn "mask failed"
systemctl daemon-reload
systemctl enable krdos-ui.service && ok "krdos-ui.service enabled" || err "enable failed"

# Belt-and-suspenders: .bash_profile starts X if somehow a shell runs on tty1
cat > /root/.bash_profile <<'BASHPROFILE'
# KrdOS: if a raw shell appears on tty1, launch X immediately
if [[ -z "$DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then
  exec xinit /etc/krdos/xinitrc -- /usr/bin/X vt1 -nolisten tcp \
    &>/var/log/krdos-x11-fallback.log
fi
BASHPROFILE
ok "Belt-and-suspenders .bash_profile written"

# =============================================================================
# STEP 8 — Networking, Bluetooth, audio services
# =============================================================================
step "8/9" "Configure NetworkManager, Bluetooth, PulseAudio"

# NetworkManager
mkdir -p /etc/NetworkManager
cat > /etc/NetworkManager/NetworkManager.conf <<'NMCONF'
[main]
plugins=ifupdown,keyfile
dhcp=internal

[ifupdown]
managed=true

[device]
wifi.scan-rand-mac-address=yes

[logging]
level=WARN
NMCONF
systemctl enable NetworkManager      && ok "NetworkManager enabled"    || warn "NM enable failed"
systemctl enable NetworkManager-dispatcher 2>/dev/null || true

# Bluetooth
mkdir -p /etc/bluetooth
cat > /etc/bluetooth/main.conf <<'BTCONF'
[Policy]
AutoEnable=true

[General]
FastConnectable=true
DiscoverableTimeout=0
Privacy=off
BTCONF
systemctl enable bluetooth           && ok "Bluetooth enabled"         || warn "BT enable failed"

# PulseAudio — started per X session from xinitrc; not a system service
systemctl disable pulseaudio.service 2>/dev/null || true
systemctl disable pulseaudio.socket  2>/dev/null || true
# Allow root-run PA to auto-spawn
mkdir -p /etc/pulse
grep -q "autospawn = yes" /etc/pulse/client.conf 2>/dev/null \
  || echo "autospawn = yes" >> /etc/pulse/client.conf
ok "PulseAudio configured (session-launched)"

# D-Bus
systemctl enable dbus 2>/dev/null || true

# =============================================================================
# STEP 9 — Power actions: reboot / shutdown work from Flutter
# =============================================================================
step "9/9" "Configure power actions, polkit, sudoers — then reboot"

# Polkit rule: any process may reboot/poweroff without authentication
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/10-krdos-power.rules <<'POLKIT'
// KrdOS: allow all users to reboot and power off without a password prompt
polkit.addRule(function(action, subject) {
    var powerActions = [
        "org.freedesktop.login1.reboot",
        "org.freedesktop.login1.reboot-multiple-sessions",
        "org.freedesktop.login1.power-off",
        "org.freedesktop.login1.power-off-multiple-sessions",
        "org.freedesktop.login1.suspend",
        "org.freedesktop.login1.hibernate"
    ];
    if (powerActions.indexOf(action.id) >= 0) {
        return polkit.Result.YES;
    }
});
POLKIT
ok "Polkit power rules written"

# Sudoers: passwordless power commands for krdos user
mkdir -p /etc/sudoers.d
cat > /etc/sudoers.d/krdos <<'SUDOERS'
Defaults:root !requiretty
root  ALL=(ALL) NOPASSWD: ALL
krdos ALL=(ALL) NOPASSWD: \
  /usr/sbin/rfkill, /usr/bin/nmcli, /sbin/modprobe, \
  /usr/bin/wg-quick, /usr/sbin/openvpn, /sbin/ip, \
  /usr/bin/macchanger, /bin/systemctl, \
  /sbin/reboot, /sbin/poweroff, /sbin/shutdown, \
  /usr/sbin/reboot, /usr/sbin/poweroff, /usr/sbin/shutdown, \
  /usr/bin/systemctl, \
  /usr/bin/amixer, /usr/bin/pactl, /sbin/fstrim, \
  /usr/local/bin/kill-switch.sh, /usr/local/bin/ip-rotator.sh, \
  /usr/local/bin/vpn-control.sh, /usr/local/bin/maintenance.sh, \
  /usr/local/bin/optimize.sh, /usr/bin/efibootmgr, \
  /usr/bin/xrandr, /usr/local/bin/krdos-configure-displays.sh
SUDOERS
chmod 440 /etc/sudoers.d/krdos
ok "Sudoers written"

# Symlinks so both /sbin/reboot and /usr/sbin/reboot exist
for cmd in reboot poweroff shutdown halt; do
  for prefix in /sbin /usr/sbin; do
    [[ -e "$prefix/$cmd" ]] || ln -sf "$(command -v $cmd)" "$prefix/$cmd" 2>/dev/null || true
  done
done
ok "Power command symlinks ensured"

# =============================================================================
# STEP 10 — Self-update infrastructure (GitHub OTA)
# =============================================================================
step "10/10" "Install krdos-update self-update tool"

# ── Create /etc/krdos/update.conf (token store) ───────────────────────────────
# This file is the single source of truth for GITHUB_REPO and GITHUB_TOKEN.
# chmod 600 / root-only: token is never committed to git or visible to other users.
# Never overwrite an existing file — the user may have already set their token.
UPDATE_CONF="/etc/krdos/update.conf"
mkdir -p /etc/krdos

if [[ ! -f "$UPDATE_CONF" ]]; then
  cat > "$UPDATE_CONF" <<'UPDATECONF'
# /etc/krdos/update.conf
# ─────────────────────────────────────────────────────────────────────────────
# KrdOS self-update configuration
# Edit this file as root.  chmod 600 is enforced below — never commit this file.
# ─────────────────────────────────────────────────────────────────────────────

# GitHub repository in the form  owner/repo
# Replace with your actual repository name.
GITHUB_REPO=escscripts/krdos

# Personal Access Token for PRIVATE repositories.
# Leave blank (or remove the line) for public repos — no token needed.
# Generate a token at: https://github.com/settings/tokens
#   Required scopes: repo (for private repos) or public_repo (for public repos)
# Example:
#   GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GITHUB_TOKEN=
UPDATECONF
  ok "Created $UPDATE_CONF (template with blank token)"
else
  ok "$UPDATE_CONF already exists — not overwritten (your token is safe)"
fi

# Lock down permissions: root read/write only, no other users
chown root:root "$UPDATE_CONF"
chmod 600 "$UPDATE_CONF"
ok "Permissions: $UPDATE_CONF  (root:root 600)"

# Warn if the token is still blank
CONF_TOKEN=$(grep -m1 '^GITHUB_TOKEN=' "$UPDATE_CONF" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]')
if [[ -z "$CONF_TOKEN" ]]; then
  warn "GITHUB_TOKEN is not set in $UPDATE_CONF"
  warn "  → For private repos, run:  sudo nano $UPDATE_CONF"
  warn "    and add:  GITHUB_TOKEN=ghp_your_token_here"
  warn "  → Public repos work without a token."
fi

# Install the update script — either from the USB/overlay or a bundled copy
if [[ -f "$SCRIPT_DIR/krdos-update.sh" ]]; then
  cp "$SCRIPT_DIR/krdos-update.sh" /usr/local/bin/krdos-update
  chmod +x /usr/local/bin/krdos-update
  ok "krdos-update installed from $SCRIPT_DIR/krdos-update.sh"
else
  # Fallback: write a minimal stub that tells the user to configure the repo
  cat > /usr/local/bin/krdos-update <<'UPDATE_STUB'
#!/bin/bash
echo "krdos-update: not configured."
echo "Edit /usr/local/bin/krdos-update and set GITHUB_REPO to your repo."
echo "Then re-run setup.sh or install the full krdos-update.sh from your repo."
UPDATE_STUB
  chmod +x /usr/local/bin/krdos-update
  warn "krdos-update stub installed — set GITHUB_REPO in the script."
fi

# Systemd timer: check for updates once per day at 03:00 (when plugged in / WiFi ready)
cat > /etc/systemd/system/krdos-update.service <<'USVC'
[Unit]
Description=KrdOS OTA Update
After=network-online.target
Wants=network-online.target
# Don't run during the kiosk session startup to avoid service race
ConditionPathExists=/opt/krdos/version

[Service]
Type=oneshot
ExecStart=/usr/local/bin/krdos-update --check
# Set to "ExecStart=/usr/local/bin/krdos-update" to auto-apply (no prompt)
StandardOutput=journal
StandardError=journal
USVC

cat > /etc/systemd/system/krdos-update.timer <<'UTIMER'
[Unit]
Description=KrdOS OTA Update Check (daily)

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
UTIMER

systemctl enable krdos-update.timer 2>/dev/null && ok "krdos-update timer enabled (daily check)" \
  || warn "Could not enable update timer"

# Add krdos-update to sudoers so it can be run without password from the Flutter terminal
# (it needs systemctl stop/start krdos-ui which requires root)
if [[ -f /etc/sudoers.d/krdos ]]; then
  grep -q "krdos-update" /etc/sudoers.d/krdos || \
    sed -i '/krdos-configure-displays.sh/a\  /usr/local/bin/krdos-update,' \
      /etc/sudoers.d/krdos
fi
ok "krdos-update wired into sudoers"

# APT cleanup
apt-get clean 2>/dev/null
rm -rf /var/lib/apt/lists/*

systemctl daemon-reload

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GRN}╔═════════════════════════════════════════════════════════════════════╗${RST}"
echo -e "${GRN}║               KrdOS Setup Complete  ✓                             ║${RST}"
echo -e "${GRN}╠═════════════════════════════════════════════════════════════════════╣${RST}"
echo -e "${GRN}║  Display   : X11 (xorg) + matchbox kiosk WM + fullscreen watchdog ║${RST}"
echo -e "${GRN}║  Resolution: auto-detected at boot, any number of monitors        ║${RST}"
echo -e "${GRN}║  Hotplug   : udev rule reconfigures displays on plug/unplug       ║${RST}"
echo -e "${GRN}║  Flutter   : $FLUTTER_APP${RST}"
echo -e "${GRN}║  WiFi      : NetworkManager + firmware (Intel/RTL/ATH/BCM/MTK)   ║${RST}"
echo -e "${GRN}║  Bluetooth : BlueZ (auto-enable on boot)                         ║${RST}"
echo -e "${GRN}║  Audio     : PulseAudio (started with X session)                 ║${RST}"
echo -e "${GRN}║  Browser   : Firefox ESR                                         ║${RST}"
echo -e "${GRN}║  Power     : reboot/shutdown via polkit + sudoers (no password)  ║${RST}"
echo -e "${GRN}║  Boot chain: systemd → krdos-ui.service → dbus-run-session       ║${RST}"
echo -e "${GRN}║              → Xorg vt1 → configure-displays → matchbox → Flutter ║${RST}"
echo -e "${GRN}║  Updates   : run 'krdos-update' in terminal (pulls from GitHub)  ║${RST}"
echo -e "${GRN}║              daily auto-check via systemd timer                  ║${RST}"
echo -e "${GRN}╠═════════════════════════════════════════════════════════════════════╣${RST}"
echo -e "${GRN}║  Rebooting in 5 seconds…                                         ║${RST}"
echo -e "${GRN}╚═════════════════════════════════════════════════════════════════════╝${RST}"
echo ""
sleep 5
reboot
