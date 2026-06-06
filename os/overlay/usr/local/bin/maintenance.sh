#!/usr/bin/env bash
# KrdOS Weekly Maintenance — runs automatically via systemd timer
# Also triggered from the Flutter Settings panel
set -euo pipefail
LOG=/var/log/krdos/maintenance.log
LAST=/var/log/krdos/last_maintenance
mkdir -p /var/log/krdos

ts() { date '+%H:%M:%S'; }

log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

log "=== KrdOS Maintenance Started ==="

# 1. Clean temp files
log "Cleaning temp files…"
find /tmp -mindepth 1 -maxdepth 1 -atime +1 -exec rm -rf {} \; 2>/dev/null || true
find /var/tmp -mindepth 1 -maxdepth 1 -atime +7 -exec rm -rf {} \; 2>/dev/null || true

# 2. APT cache
log "Cleaning apt cache…"
apt-get clean -y 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

# 3. System logs older than 7 days
log "Vacuuming system logs…"
journalctl --vacuum-time=7d 2>/dev/null || true

# 4. Thumbnail cache older than 30 days
log "Clearing old thumbnails…"
find /home/admin/.cache/thumbnails -type f -atime +30 -delete 2>/dev/null || true

# 5. SSD trim (if supported)
log "Trimming SSD…"
fstrim -av 2>/dev/null || true

# 6. Free page cache
log "Freeing cached memory…"
sync && echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true

# 7. Disk health check (non-fatal)
log "Checking disk health…"
if command -v smartctl &>/dev/null; then
  for dev in /dev/sd? /dev/nvme?; do
    [[ -b "$dev" ]] || continue
    result=$(smartctl -H "$dev" 2>/dev/null | grep -E 'result:|health' || true)
    log "  $dev: ${result:-unknown}"
    if echo "$result" | grep -qi "FAILED"; then
      echo "DISK_HEALTH_WARNING: $dev may be failing" >> "$LOG"
    fi
  done
fi

# 8. Update package lists silently
log "Updating package lists…"
apt-get update -qq 2>/dev/null || true

log "=== Maintenance Complete ==="
date > "$LAST"
