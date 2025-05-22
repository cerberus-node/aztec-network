#!/bin/bash

# Đường dẫn đến .env
ENV_FILE="./aztec-sequencer/.env"
KEY="GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS"
VALUE="0x54F7fe24E349993b363A5Fa1bccdAe2589D5E5Ef"

# Kiểm tra nếu file .env tồn tại
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ File $ENV_FILE không tồn tại!"
  exit 1
fi

# Thêm hoặc cập nhật biến môi trường
if grep -q "^${KEY}=" "$ENV_FILE"; then
  echo "🔁 Updating $KEY in $ENV_FILE..."
  sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$ENV_FILE"
else
  echo "➕ Adding $KEY to $ENV_FILE..."
  echo "${KEY}=${VALUE}" >> "$ENV_FILE"
fi

# Restart container
echo "♻️ Restarting container to apply changes..."
cd ./aztec-sequencer
docker compose --env-file .env down
docker compose --env-file .env up -d

echo "✅ Done. $KEY is now active."
