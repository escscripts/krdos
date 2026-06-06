#!/usr/bin/env bash
# KrdOS One-Time Speed Optimization
# Called by Flutter SystemBridge.systemOptimize() and also on first boot
set -euo pipefail

log() { echo "[optimize] $*"; }

# 1. CPU governor → performance
log "Setting CPU governor to performance…"
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance > "$cpu" 2>/dev/null || true
done

# 2. Swappiness → 10 (prefer RAM over swap)
log "Setting swappiness to 10…"
sysctl -w vm.swappiness=10 2>/dev/null || true
echo "vm.swappiness=10" >> /etc/sysctl.d/99-krdos.conf 2>/dev/null || true

# 3. Dirty ratio — flush writes more aggressively (less stalling)
sysctl -w vm.dirty_ratio=10 2>/dev/null || true
sysctl -w vm.dirty_background_ratio=5 2>/dev/null || true

# 4. SSD I/O scheduler → mq-deadline or none
log "Setting I/O scheduler…"
for device in /sys/block/sd? /sys/block/nvme?n?; do
  [[ -d "$device" ]] || continue
  if echo mq-deadline > "$device/queue/scheduler" 2>/dev/null; then
    log "  $(basename $device): mq-deadline"
  elif echo none > "$device/queue/scheduler" 2>/dev/null; then
    log "  $(basename $device): none (NVMe)"
  fi
done

# 5. zRAM (compressed RAM swap) — up to half of total RAM
log "Setting up zRAM…"
if modprobe zram 2>/dev/null; then
  TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  ZRAM_SIZE=$((TOTAL_RAM * 512)) # 512 bytes per KB = half in bytes
  echo "${ZRAM_SIZE}" > /sys/block/zram0/disksize 2>/dev/null || true
  mkswap /dev/zram0 2>/dev/null || true
  swapon -p 100 /dev/zram0 2>/dev/null || true
  log "  zRAM: ${ZRAM_SIZE} bytes"
fi

# 6. Enable TRIM service
log "Enabling periodic TRIM…"
systemctl enable fstrim.timer 2>/dev/null || true
systemctl start  fstrim.timer 2>/dev/null || true

# 7. Preload (if available)
if command -v preload &>/dev/null; then
  systemctl enable preload 2>/dev/null || true
  systemctl start  preload 2>/dev/null || true
fi

# 8. Disable unnecessary services for KrdOS
for svc in bluetooth avahi-daemon cups ModemManager; do
  systemctl disable "$svc" 2>/dev/null || true
  systemctl stop    "$svc" 2>/dev/null || true
done

# 9. Huge pages
log "Enabling huge pages…"
sysctl -w vm.nr_hugepages=128 2>/dev/null || true

# 10. ext4 remount with noatime (faster reads)
log "Enabling noatime…"
if mountpoint -q /; then
  mount -o remount,noatime / 2>/dev/null || true
fi

log "Optimization complete."
