#!/usr/bin/env bash
# VPN control — connect / disconnect / status for WireGuard and OpenVPN.
# Usage:
#   vpn-control.sh connect wireguard /etc/wireguard/wg0.conf
#   vpn-control.sh connect openvpn   /etc/openvpn/client.ovpn
#   vpn-control.sh disconnect
#   vpn-control.sh status
set -euo pipefail

CMD="${1:-status}"

case "$CMD" in
  connect)
    PROTOCOL="${2:-wireguard}"
    CONFIG="${3:-}"
    [[ -z "$CONFIG" ]] && { echo "Usage: $0 connect <protocol> <config>"; exit 1; }

    case "$PROTOCOL" in
      wireguard)
        IFACE=$(basename "$CONFIG" .conf)
        wg-quick up "$CONFIG" 2>&1
        echo "WireGuard connected — interface $IFACE"
        ;;
      openvpn)
        openvpn --config "$CONFIG" --daemon --log /var/log/openvpn.log
        sleep 2
        echo "OpenVPN connecting — see /var/log/openvpn.log"
        ;;
      *)
        echo "Unknown protocol: $PROTOCOL (use wireguard or openvpn)"
        exit 1
        ;;
    esac
    ;;

  disconnect)
    # WireGuard
    for iface in $(wg show interfaces 2>/dev/null); do
      wg-quick down "$iface" 2>/dev/null && echo "WireGuard $iface down"
    done
    # OpenVPN
    pkill openvpn 2>/dev/null && echo "OpenVPN stopped" || true
    echo "VPN disconnected"
    ;;

  status)
    echo "=== WireGuard ==="
    wg show 2>/dev/null || echo "  not connected"
    echo ""
    echo "=== OpenVPN ==="
    pgrep -a openvpn 2>/dev/null || echo "  not running"
    ;;

  *)
    echo "Usage: $0 connect|disconnect|status"
    exit 1
    ;;
esac
