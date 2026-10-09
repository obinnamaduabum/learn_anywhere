#!/bin/bash
set -euo pipefail

# Use the current Wi-Fi address; no device data is cleared.
mode=debug
device=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) mode=release; shift ;;
    --debug) mode=debug; shift ;;
    --device) device="${2:?Provide an iPhone device ID}"; shift 2 ;;
    *) echo "Usage: $0 [--debug|--release] --device <iPhone ID>" >&2; exit 2 ;;
  esac
done
if [[ -z "$device" ]]; then
  echo "Choose your iPhone ID from 'flutter devices' and pass --device <ID>." >&2
  exit 2
fi
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
backend_url="${LEARNING_API_URL:-}"
if [[ -z "$backend_url" ]]; then
  wifi_interface="${WIFI_INTERFACE:-$(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: (Wi-Fi|AirPort)/ {getline; print $2; exit}' || true)}"
  wifi_address="$(ipconfig getifaddr "$wifi_interface" 2>/dev/null || true)"
  if [[ -z "$wifi_address" ]]; then
    echo "No Wi-Fi address found. Connect to Wi-Fi or set LEARNING_API_URL." >&2
    exit 1
  fi
  backend_url="http://${wifi_address}:8084"
fi
if ! curl --fail --silent --show-error --max-time 5 "$backend_url/api/v1/health" >/dev/null; then
  echo "Backend unavailable at $backend_url. Start the backend and check the Mac firewall." >&2
  exit 1
fi
cd "$project_dir"
echo "Running $mode on $device with $backend_url"
exec "${FLUTTER_BIN:-flutter}" run "--$mode" -d "$device" \
  "--dart-define=LEARNING_API_URL=$backend_url" \
  --dart-define=ALLOW_LOCAL_DEMO_HTTP=true
