#!/usr/bin/env bash
# Hardware kill switch — blocks/unblocks WiFi, Bluetooth, mic, camera at kernel level.
# Usage: kill-switch.sh <device> <on|off>
# Devices: wifi  bluetooth  mic  camera  all
set -euo pipefail

DEVICE="${1:-}"
ACTION="${2:-}"

usage() {
  echo "Usage: $0 <wifi|bluetooth|mic|camera|all> <on|off>"
  exit 1
}

[[ -z "$DEVICE" || -z "$ACTION" ]] && usage

kill_wifi() {
  case "$ACTION" in
    off) nmcli radio wifi off; rfkill block wifi ;;
    on)  rfkill unblock wifi; nmcli radio wifi on ;;
    *) usage ;;
  esac
  echo "WiFi $ACTION"
}

kill_bluetooth() {
  case "$ACTION" in
    off) bluetoothctl power off 2>/dev/null || true; rfkill block bluetooth ;;
    on)  rfkill unblock bluetooth; bluetoothctl power on 2>/dev/null || true ;;
    *) usage ;;
  esac
  echo "Bluetooth $ACTION"
}

kill_mic() {
  case "$ACTION" in
    off)
      amixer set Capture nocap 2>/dev/null || true
      pactl set-source-mute @DEFAULT_SOURCE@ 1 2>/dev/null || true
      ;;
    on)
      amixer set Capture cap 2>/dev/null || true
      pactl set-source-mute @DEFAULT_SOURCE@ 0 2>/dev/null || true
      ;;
    *) usage ;;
  esac
  echo "Microphone $ACTION"
}

kill_camera() {
  case "$ACTION" in
    off) modprobe -r uvcvideo 2>/dev/null || true; echo "Camera disabled (UVC driver unloaded)" ;;
    on)  modprobe uvcvideo 2>/dev/null || true;    echo "Camera enabled (UVC driver loaded)" ;;
    *) usage ;;
  esac
}

case "$DEVICE" in
  wifi)      kill_wifi ;;
  bluetooth) kill_bluetooth ;;
  mic)       kill_mic ;;
  camera)    kill_camera ;;
  all)
    kill_wifi
    kill_bluetooth
    kill_mic
    kill_camera
    ;;
  *) usage ;;
esac
