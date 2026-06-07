#!/usr/bin/env bash
# =============================================================================
# KrdOS Installer  v4.0  — NO debootstrap, NO live-apt dependency
# =============================================================================
# USAGE:  sudo bash install.sh
#
# ASSUMES:
#   /dev/sda1  — EFI System Partition (FAT32, already exists)
#   /dev/sda2  — root partition       (will be WIPED and formatted ext4)
#   UEFI firmware, Secure Boot OFF
#   Internet connection (needed for base tarball + package install)
#
# HOW IT GETS A BASE SYSTEM (no debootstrap):
#   1. Tries pacstrap   (present on Arch-based live)
#   2. Tries mmdebstrap (present on some Debian-based live)
#   3. Downloads Debian bookworm slim rootfs tarball directly via curl/wget
#      → no apt-get on the live system is needed at all
# =============================================================================

# ── Never abort on error — every command uses || err / || warn ───────────────

ROOT_PART="/dev/sda2"
EFI_PART="/dev/sda1"
MOUNT="/mnt/krdos"

# Debian bookworm slim (~30 MB xz).  This is the debuerreotype Docker base image
# used by the official Debian Docker Hub image — stable and always current.
BASE_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/dist-amd64/bookworm/slim/rootfs.tar.xz"

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

# ── Root check ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Run as root:  sudo bash install.sh${RST}"; exit 1
fi

echo ""
echo -e "${CYN}  KrdOS Installer v4.0${RST}"
echo "  Root partition  :  $ROOT_PART  (will be ERASED)"
echo "  EFI  partition  :  $EFI_PART"
echo "  Mount point     :  $MOUNT"
echo "  Base system     :  Debian bookworm slim (downloaded, no debootstrap)"
echo ""
read -r -p "  Type YES to continue: " CONFIRM
[[ "$CONFIRM" == "YES" ]] || { echo "Aborted."; exit 0; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ -b "$ROOT_PART" ]] || { echo -e "${RED}$ROOT_PART not found.${RST}"; exit 1; }
[[ -b "$EFI_PART"  ]] || warn "$EFI_PART not found — GRUB EFI will likely fail"

# ── Network check ─────────────────────────────────────────────────────────────
info "Checking internet connectivity…"
if ping -c1 -W3 8.8.8.8 &>/dev/null || ping -c1 -W3 1.1.1.1 &>/dev/null; then
  ok "Internet reachable"
else
  warn "No internet detected — tarball download and package install will fail"
fi

# =============================================================================
# STEP 1 — Format /dev/sda2 as ext4
# =============================================================================
step "1/9" "Format /dev/sda2 as ext4"

mkfs.ext4 -F -L krdos_root "$ROOT_PART" \
  && ok "Formatted $ROOT_PART as ext4 (label: krdos_root)" \
  || err "mkfs.ext4 failed on $ROOT_PART"

# =============================================================================
# STEP 2 — Mount /dev/sda2 to /mnt/krdos
# =============================================================================
step "2/9" "Mount /dev/sda2 to /mnt/krdos"

mkdir -p "$MOUNT"
mount "$ROOT_PART" "$MOUNT" \
  && ok "Mounted $ROOT_PART → $MOUNT" \
  || { echo -e "${RED}Cannot mount $ROOT_PART — aborting.${RST}"; exit 1; }

# =============================================================================
# STEP 3 — Get a base system (no debootstrap)
# =============================================================================
step "3/9" "Install base system (no debootstrap)"

BASE_OK=false

# ── Option A: pacstrap (Arch-based live USB) ──────────────────────────────────
if command -v pacstrap &>/dev/null; then
  info "pacstrap detected — using it for base install…"
  pacstrap "$MOUNT" base systemd linux grub efibootmgr \
    && { ok "pacstrap base installed"; BASE_OK=true; } \
    || warn "pacstrap failed — falling through to tarball download"
fi

# ── Option B: mmdebstrap ──────────────────────────────────────────────────────
if [[ "$BASE_OK" == false ]] && command -v mmdebstrap &>/dev/null; then
  info "mmdebstrap detected — using it…"
  mmdebstrap --arch=amd64 --variant=minbase bookworm "$MOUNT" \
    'deb http://deb.debian.org/debian bookworm main' \
    && { ok "mmdebstrap base installed"; BASE_OK=true; } \
    || warn "mmdebstrap failed — falling through to tarball download"
fi

# ── Option C: Download Debian bookworm slim rootfs tarball ───────────────────
if [[ "$BASE_OK" == false ]]; then
  info "Downloading Debian bookworm slim rootfs (~30 MB)…"
  info "URL: $BASE_URL"

  TARBALL="/tmp/rootfs.tar.xz"

  # Try curl first, then wget
  if command -v curl &>/dev/null; then
    curl -fL --retry 3 --retry-delay 2 --progress-bar \
      -o "$TARBALL" "$BASE_URL" \
      && ok "Downloaded via curl" \
      || { warn "curl failed — trying wget…"
           wget -q --show-progress --tries=3 -O "$TARBALL" "$BASE_URL" \
             && ok "Downloaded via wget" \
             || { err "Both curl and wget failed — cannot get base system"; TARBALL=""; } }
  elif command -v wget &>/dev/null; then
    wget -q --show-progress --tries=3 -O "$TARBALL" "$BASE_URL" \
      && ok "Downloaded via wget" \
      || { err "wget failed — cannot get base system"; TARBALL=""; }
  else
    err "Neither curl nor wget found — cannot download base tarball"
    TARBALL=""
  fi

  # Extract tarball
  if [[ -n "$TARBALL" && -f "$TARBALL" ]]; then
    info "Extracting rootfs to $MOUNT…"
    # Try tar with native xz support first; fall back to xz pipe
    if tar -xJf "$TARBALL" -C "$MOUNT" 2>/dev/null; then
      ok "Extracted rootfs (tar -xJ)"
      BASE_OK=true
    elif xz -d < "$TARBALL" | tar -xf - -C "$MOUNT"; then
      ok "Extracted rootfs (xz pipe)"
      BASE_OK=true
    else
      err "Extraction failed — rootfs may be corrupt or xz not available"
    fi
    rm -f "$TARBALL"
  fi
fi

if [[ "$BASE_OK" == false ]]; then
  echo -e "${RED}  FATAL: Could not get a base system by any method.${RST}"
  echo    "  Check internet connection and try again."
  umount "$MOUNT" 2>/dev/null
  exit 1
fi

# =============================================================================
# STEP 4 — Copy overlay to /mnt/krdos
# =============================================================================
step "4/9" "Copy overlay folder contents to /mnt/krdos"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="$SCRIPT_DIR/overlay"

info "Overlay source: $OVERLAY_DIR"

if [[ -d "$OVERLAY_DIR" ]]; then
  # rsync preserves permissions, symlinks, timestamps
  rsync -a "$OVERLAY_DIR/" "$MOUNT/" \
    && ok "Overlay copied to $MOUNT" \
    || err "rsync reported errors copying overlay"
else
  warn "Overlay directory not found at $OVERLAY_DIR"
  info "Flutter shell and system scripts will be missing"
fi

# =============================================================================
# STEP 5 — Bind /dev /proc /sys inside chroot
# =============================================================================
step "5/9" "Bind-mount /dev /proc /sys into chroot"

mount --bind /dev       "$MOUNT/dev"      2>/dev/null \
  && info "bound /dev"      || warn "/dev bind failed"
mount --bind /proc      "$MOUNT/proc"     2>/dev/null \
  && info "bound /proc"     || warn "/proc bind failed"
mount --bind /sys       "$MOUNT/sys"      2>/dev/null \
  && info "bound /sys"      || warn "/sys bind failed"
mount -t devpts devpts  "$MOUNT/dev/pts"  2>/dev/null \
  && info "bound /dev/pts"  || warn "/dev/pts bind failed"

# EFI partition — needed for grub-install
mkdir -p "$MOUNT/boot/efi"
mount "$EFI_PART" "$MOUNT/boot/efi" 2>/dev/null \
  && info "mounted $EFI_PART → /boot/efi" \
  || warn "$EFI_PART could not be mounted at /boot/efi — grub-install will fail"

# efivars — needed for GRUB to register UEFI NVRAM entry
if [[ -d /sys/firmware/efi/efivars ]]; then
  mkdir -p "$MOUNT/sys/firmware/efi/efivars"
  mount --bind /sys/firmware/efi/efivars "$MOUNT/sys/firmware/efi/efivars" 2>/dev/null \
    || mount -t efivarfs efivarfs "$MOUNT/sys/firmware/efi/efivars" 2>/dev/null \
    || warn "efivars not mountable — grub-install will use --no-nvram"
  info "efivars bound"
else
  warn "No efivars on live system — is UEFI mode active?"
fi

ok "Virtual filesystems ready"

# ── DNS inside chroot ─────────────────────────────────────────────────────────
cp /etc/resolv.conf "$MOUNT/etc/resolv.conf" 2>/dev/null \
  && info "resolv.conf copied for in-chroot DNS" \
  || warn "Could not copy resolv.conf — apt may fail DNS lookup"

# ── APT sources (Debian bookworm + security) ──────────────────────────────────
cat > "$MOUNT/etc/apt/sources.list" <<'SOURCES'
deb http://deb.debian.org/debian          bookworm         main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian          bookworm-updates main contrib non-free non-free-firmware
SOURCES
ok "APT sources written (Debian bookworm)"

# Convenience wrapper — all chroot commands go through this
cx() { chroot "$MOUNT" /bin/bash -c "$*"; }

info "Updating package lists inside chroot…"
cx "apt-get update -qq" 2>/dev/null \
  && ok "apt-get update OK" \
  || warn "apt-get update failed — package install may fail"

# =============================================================================
# STEP 6 — Install grub-efi-amd64 and linux-image-amd64 inside chroot
# =============================================================================
step "6/9" "Install grub-efi-amd64, linux-image-amd64, and runtime packages"

info "This downloads ~300 MB of packages — takes 5–15 minutes…"

DEBIAN_FRONTEND=noninteractive cx \
  "apt-get install -y --no-install-recommends \
     linux-image-amd64 \
     grub-efi-amd64 grub-efi-amd64-bin \
     efibootmgr \
     systemd systemd-sysv dbus \
     network-manager \
     sudo \
     weston xwayland \
     libwayland-client0 libwayland-server0 libwayland-egl1 \
     libgl1-mesa-dri \
     libglib2.0-0 libgtk-3-0 \
     libwebkit2gtk-4.1-0 libjavascriptcoregtk-4.1-0 \
     alsa-utils \
     curl ca-certificates \
     iproute2 iputils-ping \
     procps htop kmod \
     locales \
     util-linux 2>&1" \
  && ok "All packages installed" \
  || err "Some packages failed — system may still boot"

# ── System identity ───────────────────────────────────────────────────────────
echo "krdos" > "$MOUNT/etc/hostname"
cat > "$MOUNT/etc/hosts" <<'HOSTS'
127.0.0.1   localhost
127.0.1.1   krdos
::1         localhost ip6-localhost ip6-loopback
HOSTS

echo "en_US.UTF-8 UTF-8" > "$MOUNT/etc/locale.gen"
cx "locale-gen" 2>/dev/null || true
echo "LANG=en_US.UTF-8" > "$MOUNT/etc/default/locale"
echo "Etc/UTC"           > "$MOUNT/etc/timezone"
cx "dpkg-reconfigure -f noninteractive tzdata" 2>/dev/null || true
ok "Hostname, locale, timezone configured"

# ── Users ─────────────────────────────────────────────────────────────────────
cx "id krdos &>/dev/null || useradd -m -s /bin/bash -G sudo,audio,video,input krdos 2>/dev/null || true"
cx "echo 'krdos:krdos' | chpasswd" 2>/dev/null || true
cx "passwd -d root" 2>/dev/null || true

mkdir -p "$MOUNT/etc/sudoers.d"
cat > "$MOUNT/etc/sudoers.d/krdos" <<'SUDOERS'
Defaults:root !requiretty
root  ALL=(ALL) NOPASSWD: ALL
krdos ALL=(ALL) NOPASSWD: ALL
SUDOERS
chmod 440 "$MOUNT/etc/sudoers.d/krdos"
ok "User krdos created (password: krdos)"

# ── fstab ─────────────────────────────────────────────────────────────────────
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART" 2>/dev/null || echo "")
EFI_UUID=$(blkid  -s UUID -o value "$EFI_PART"  2>/dev/null || echo "")

if [[ -n "$ROOT_UUID" && -n "$EFI_UUID" ]]; then
  cat > "$MOUNT/etc/fstab" <<FSTAB
# KrdOS fstab — generated by installer
UUID=$ROOT_UUID  /          ext4  relatime,errors=remount-ro  0 1
UUID=$EFI_UUID   /boot/efi  vfat  umask=0077,noatime          0 1
tmpfs            /tmp       tmpfs defaults,noatime             0 0
FSTAB
  ok "fstab written (UUID-based)"
else
  cat > "$MOUNT/etc/fstab" <<FSTAB
# KrdOS fstab — device paths (UUID lookup failed)
$ROOT_PART  /          ext4  relatime,errors=remount-ro  0 1
$EFI_PART   /boot/efi  vfat  umask=0077,noatime          0 1
tmpfs       /tmp       tmpfs defaults,noatime             0 0
FSTAB
  warn "fstab written with device paths (blkid UUID lookup failed)"
fi

# ── Systemd services (safety net — overlay should already have these) ─────────
mkdir -p "$MOUNT/etc/systemd/system/getty@tty1.service.d"
cat > "$MOUNT/etc/systemd/system/getty@tty1.service.d/override.conf" <<'GETTY'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
GETTY

if [[ ! -f "$MOUNT/etc/systemd/system/weston.service" ]]; then
  cat > "$MOUNT/etc/systemd/system/weston.service" <<'WESTON'
[Unit]
Description=Weston Wayland Compositor
After=systemd-udev-settle.service systemd-logind.service
Requires=systemd-logind.service

[Service]
Type=simple
User=root
PAMName=login
TTYPath=/dev/tty2
StandardInput=tty
UtmpIdentifier=tty2
Environment=XDG_RUNTIME_DIR=/run/user/0
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus
Environment=WLR_NO_HARDWARE_CURSORS=1
ExecStartPre=/bin/mkdir -p /run/user/0
ExecStartPre=/bin/chmod 700 /run/user/0
ExecStart=/bin/sh -c '\
  weston --backend=drm --xwayland --idle-time=0 --log=/var/log/weston.log || \
  weston --backend=fbdev --xwayland --idle-time=0 --log=/var/log/weston.log || \
  weston --backend=headless --xwayland --idle-time=0 --log=/var/log/weston.log'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
WESTON
fi

if [[ ! -f "$MOUNT/etc/systemd/system/krdos.service" ]]; then
  cat > "$MOUNT/etc/systemd/system/krdos.service" <<'KRDOS'
[Unit]
Description=KrdOS Flutter Shell
After=weston.service network.target
Wants=weston.service

[Service]
Type=simple
User=root
Environment=XDG_RUNTIME_DIR=/run/user/0
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-0
Environment=KRDOS_SHELL=1
Environment=HOME=/root
WorkingDirectory=/opt/krdos
ExecStartPre=/bin/sh -c 'for i in $(seq 1 30); do [ -e /tmp/.X0-lock ] && exit 0; sleep 0.5; done; exit 1'
ExecStart=/opt/krdos/krdos
Restart=always
RestartSec=2
RestartForceExitStatus=1 6

[Install]
WantedBy=multi-user.target
KRDOS
fi

mkdir -p "$MOUNT/etc/xdg/weston"
if [[ ! -f "$MOUNT/etc/xdg/weston/weston.ini" ]]; then
  cat > "$MOUNT/etc/xdg/weston/weston.ini" <<'WESTONINI'
[core]
idle-time=0
require-input=false

[shell]
locking=false
panel-position=none
WESTONINI
fi

cx "systemctl enable weston.service"  2>/dev/null && ok "weston enabled"       || err "weston enable failed"
cx "systemctl enable krdos.service"   2>/dev/null && ok "krdos enabled"        || err "krdos enable failed"
cx "systemctl enable NetworkManager"  2>/dev/null && ok "NetworkManager enabled" || warn "NetworkManager enable failed"
cx "systemctl enable getty@tty1"      2>/dev/null || true
cx "systemctl disable gdm lightdm sddm xdm 2>/dev/null" || true

# ── GRUB config ───────────────────────────────────────────────────────────────
cat > "$MOUNT/etc/default/grub" <<'GRUBCONF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_DISTRIBUTOR="KrdOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=0 vt.handoff=7"
GRUB_CMDLINE_LINUX=""
GRUB_DISABLE_OS_PROBER=true
GRUB_TERMINAL_OUTPUT=console
GRUBCONF
ok "GRUB config written"

# ── APT cleanup ───────────────────────────────────────────────────────────────
cx "apt-get clean" 2>/dev/null || true
cx "rm -rf /var/lib/apt/lists/*" 2>/dev/null || true

# =============================================================================
# STEP 7 — grub-install
# =============================================================================
step "7/9" "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=KrdOS"

# Try primary, then --no-nvram, then --removable (each handles a different firmware quirk)
if cx "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=KrdOS --recheck 2>&1"; then
  ok "grub-install succeeded"
elif cx "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=KrdOS --no-nvram --recheck 2>&1"; then
  ok "grub-install succeeded (--no-nvram)"
elif cx "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=KrdOS --removable --recheck 2>&1"; then
  ok "grub-install succeeded (--removable / fallback EFI path)"
else
  err "All grub-install attempts failed — system may not boot without manual GRUB setup"
fi

# =============================================================================
# STEP 8 — update-grub
# =============================================================================
step "8/9" "update-grub"

cx "update-grub 2>&1" \
  && ok "update-grub complete — GRUB menu entries generated" \
  || err "update-grub reported errors"

# =============================================================================
# STEP 9 — Unmount and reboot
# =============================================================================
step "9/9" "Unmount filesystems and reboot"

info "Flushing disk writes…"
sync

info "Unmounting in reverse order…"
umount "$MOUNT/sys/firmware/efi/efivars"  2>/dev/null && info "efivars unmounted"  || true
umount "$MOUNT/dev/pts"                   2>/dev/null && info "/dev/pts unmounted" || true
umount "$MOUNT/dev"                       2>/dev/null && info "/dev unmounted"     || true
umount "$MOUNT/proc"                      2>/dev/null && info "/proc unmounted"    || true
umount "$MOUNT/sys"                       2>/dev/null && info "/sys unmounted"     || true
umount "$MOUNT/boot/efi"                  2>/dev/null && info "/boot/efi unmounted" || warn "/boot/efi busy — will clear on reboot"
umount "$MOUNT"                           2>/dev/null && ok   "Root unmounted cleanly" || warn "Root still busy — kernel will clean up on reboot"

echo ""
echo -e "${GRN}╔══════════════════════════════════════════════════════════════╗${RST}"
echo -e "${GRN}║             KrdOS Installation Complete  ✓                 ║${RST}"
echo -e "${GRN}╠══════════════════════════════════════════════════════════════╣${RST}"
echo -e "${GRN}║  Root    :  $ROOT_PART  (ext4)                               ║${RST}"
echo -e "${GRN}║  EFI     :  $EFI_PART  (FAT32)                               ║${RST}"
echo -e "${GRN}║  Base    :  Debian bookworm                                 ║${RST}"
echo -e "${GRN}║  Login   :  user=krdos  password=krdos                     ║${RST}"
echo -e "${GRN}║  Chain   :  GRUB EFI → Linux kernel → systemd → Weston → Flutter ║${RST}"
echo -e "${GRN}╠══════════════════════════════════════════════════════════════╣${RST}"
echo -e "${GRN}║  Remove USB.  Rebooting in 5 seconds…                      ║${RST}"
echo -e "${GRN}╚══════════════════════════════════════════════════════════════╝${RST}"
echo ""

sleep 5
reboot
