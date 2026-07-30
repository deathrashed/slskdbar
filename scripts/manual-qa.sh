#!/bin/bash
set -euo pipefail

APP_PATH=${SLSKDBAR_APP_PATH:-"/Applications/slskdbar.app"}
CONFIG_PATH=${SLSKD_CONFIG_PATH:-"$HOME/Library/Application Support/slskd/slskd.yml"}
API_KEY=$(awk '
  /^[[:space:]]*api_keys:/ { in_keys=1; keys_indent=match($0,/[^ ]/)-1; next }
  in_keys {
    indent=match($0,/[^ ]/)-1
    if ($0 !~ /^[[:space:]]*$/ && indent <= keys_indent) in_keys=0
    if (in_keys && $0 ~ /^[[:space:]]*key:[[:space:]]*/) {
      sub(/^[[:space:]]*key:[[:space:]]*/, "", $0)
      print
      exit
    }
  }
' "$CONFIG_PATH")

curl --fail --silent --show-error http://localhost:5030/ >/dev/null
curl --fail --silent --show-error \
  -H "X-API-Key: $API_KEY" \
  http://localhost:5030/api/v0/server >/dev/null
plutil -lint "$APP_PATH/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

APP_PID=$(pgrep -f "$APP_PATH/Contents/MacOS/slskdbar" | head -1)
if [[ -z "$APP_PID" ]]; then
  echo "Installed slskdbar process not found"
  exit 1
fi

sleep 30
ps -p "$APP_PID" -o pid=,%cpu=,rss=,etime=,command=
echo "Live smoke checks passed"
