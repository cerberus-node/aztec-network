#!/bin/bash
set -e

# Config
IMAGE_TAG="aztecprotocol/aztec:2.1.2"
COMPOSE_FILE="docker-compose.yml"

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ $COMPOSE_FILE not found in current directory. Please run this script in the folder containing your docker-compose.yml."
  exit 1
fi

# Backup
echo "📁 Backing up $COMPOSE_FILE to ${COMPOSE_FILE}.bak..."
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.bak"

# Update image version
echo "🔍 Updating image version in $COMPOSE_FILE..."
sed -i "s|image: aztecprotocol/aztec:.*|image: ${IMAGE_TAG}|" "$COMPOSE_FILE"

# Stop container
echo "🛑 Stopping container..."
docker compose down || true

# Delete old data
echo "🧹 Removing old database..."
rm -rf ./data || true

# Pull image
echo "⬇️ Pulling image $IMAGE_TAG..."
docker pull "$IMAGE_TAG"

# Start container
echo "🚀 Starting upgraded node..."
docker compose --env-file .env up -d

# Show logs
echo "📄 Upgrade complete. Showing logs..."
docker logs -f --tail=100 aztec-sequencer
