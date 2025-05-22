#!/bin/bash

ENV_FILE="./aztec-sequencer/.env"
KEY="GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS"
VALUE="0x54F7fe24E349993b363A5Fa1bccdAe2589D5E5Ef"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ File $ENV_FILE not found."
  exit 1
fi

if grep -q "^${KEY}=" "$ENV_FILE"; then
  echo "🔁 Updating $KEY in $ENV_FILE..."
  sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$ENV_FILE"
else
  echo "➕ Adding $KEY to $ENV_FILE..."
  echo "${KEY}=${VALUE}" >> "$ENV_FILE"
fi

echo "✅ $KEY added/updated successfully."
