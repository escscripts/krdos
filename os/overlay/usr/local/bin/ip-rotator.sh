#!/usr/bin/env bash
# IP rotator — randomises MAC address on a given interface so the device
# gets a fresh DHCP lease (new local IP) and appears as a different device
# on the network.  Does NOT change your public IP unless paired with a VPN.
# Usage: ip-rotator.sh [interface]   (defaults to first non-lo interface)
set -euo pipefail

IFACE="${1:-}"

# Auto-detect first non-loopback interface
if [[ -z "$IFACE" ]]; then
  IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
fi

if [[ -z "$IFACE" ]]; then
  echo "No network interface found" >&2
  exit 1
fi

echo "[ip-rotator] Interface: $IFACE"
echo "[ip-rotator] Current MAC: $(cat /sys/class/net/$IFACE/address)"

# Bring interface down, randomise MAC, bring back up
ip link set "$IFACE" down
macchanger -r "$IFACE"
ip link set "$IFACE" up

echo "[ip-rotator] New MAC: $(cat /sys/class/net/$IFACE/address)"

# Request a fresh DHCP lease
if command -v dhclient &>/dev/null; then
  dhclient -r "$IFACE" 2>/dev/null || true
  dhclient "$IFACE" 2>/dev/null || true
elif command -v udhcpc &>/dev/null; then
  udhcpc -i "$IFACE" -q 2>/dev/null || true
fi

echo "[ip-rotator] Done — new lease obtained"
