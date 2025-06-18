#!/bin/bash

REMOTE_API="https://aztec.denodes.app/api/info"

# Check if any app is running on port 8080
if lsof -i :8080 >/dev/null 2>&1; then
  echo "✅ Detected app running on port 8080"
  PORT=8080
else
  read -p "⚠️ No app found on port 8080. Please enter your local Aztec RPC port: " PORT
fi

LOCAL_RPC="http://localhost:$PORT"

while true; do
  echo "🔍 Checking Aztec node sync status at $(date '+%Y-%m-%d %H:%M:%S')"

  # Check LOCAL node status
  LOCAL_RESPONSE=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$LOCAL_RPC")

  if [ -z "$LOCAL_RESPONSE" ] || [[ "$LOCAL_RESPONSE" == *"error"* ]]; then
    echo "❌ Local node not responding or returned an error. Please check if it's running on $LOCAL_RPC"
    LOCAL="N/A"
  else
    LOCAL=$(echo "$LOCAL_RESPONSE" | jq -r ".result.proven.number")
  fi

  # Check REMOTE node status
  REMOTE_RESPONSE=$(curl -s -m 5 "$REMOTE_API")

  if [ -z "$REMOTE_RESPONSE" ] || [[ "$REMOTE_RESPONSE" == *"error"* ]]; then
    echo "⚠️ Remote API ($REMOTE_API) not responding or returned an error."
    REMOTE="N/A"
  else
    REMOTE=$(echo "$REMOTE_RESPONSE" | jq -r ".blockNumber")
  fi

  echo "🧱 Local block:  $LOCAL"
  echo "🌐 Remote block: $REMOTE"

  if [[ "$LOCAL" == "N/A" ]] || [[ "$REMOTE" == "N/A" ]]; then
    echo "🚫 Cannot determine sync status due to an error in one of the responses."
  elif [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Your node is fully synced!"
  else
    echo "⏳ Still syncing... ($LOCAL / $REMOTE)"
  fi

  echo "-------------------------------"
  sleep 10
done
