#!/bin/bash

# Resolve the full path to the .env file
ENV_FILE="$HOME/aztec-sequencer/.env"
KEY="GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS"
VALUE="0x54F7fe24E349993b363A5Fa1bccdAe2589D5E5Ef"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ File $ENV_FILE not found!"
  exit 1
fi

# Add or update the variable
if grep -q "^${KEY}=" "$ENV_FILE"; then
  echo "🔁 Updating $KEY in $ENV_FILE..."
  sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$ENV_FILE"
else
  echo "➕ Adding $KEY to $ENV_FILE..."
  echo "${KEY}=${VALUE}" >> "$ENV_FILE"
fi

# Restart the container using Docker Compose
cd "$HOME/aztec-sequencer"
echo "♻️ Restarting Aztec container..."
docker compose --env-file .env down
docker compose --env-file .env up -d

echo "✅ Update complete. $KEY is now active."
