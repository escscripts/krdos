#!/usr/bin/env bash
# Network monitor — prints live RX/TX stats for all interfaces every second.
# Outputs JSON lines so the Flutter app can parse them easily.
# Usage: net-monitor.sh [interval_seconds]
INTERVAL="${1:-1}"

declare -A prev_rx prev_tx

print_stats() {
  echo "{"
  first=true
  while IFS=: read -r iface data; do
    iface="${iface// /}"
    [[ "$iface" == "lo" || -z "$iface" ]] && continue
    read -r rx_bytes _ _ _ _ _ _ _ tx_bytes _ < <(echo "$data")
    if [[ -n "${prev_rx[$iface]:-}" ]]; then
      drx=$((rx_bytes - prev_rx[$iface]))
      dtx=$((tx_bytes - prev_tx[$iface]))
    else
      drx=0; dtx=0
    fi
    prev_rx[$iface]=$rx_bytes
    prev_tx[$iface]=$tx_bytes
    $first || echo ","
    first=false
    printf '  "%s": {"rx_bytes": %d, "tx_bytes": %d, "rx_rate": %d, "tx_rate": %d}' \
      "$iface" "$rx_bytes" "$tx_bytes" "$drx" "$dtx"
  done < <(tail -n +3 /proc/net/dev)
  echo ""
  echo "}"
}

while true; do
  print_stats
  sleep "$INTERVAL"
done
