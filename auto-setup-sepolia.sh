#!/bin/bash

# 🚀 Auto Setup Sepolia Geth + Beacon (Prysm or Lighthouse) for Aztec Sequencer
# Assumes system has at least 1TB NVMe, 16GB RAM

set -e

# === CONFIG ===
DATA_DIR="$HOME/sepolia-node"
GETH_DIR="$DATA_DIR/geth"
JWT_FILE="$DATA_DIR/jwt.hex"
COMPOSE_FILE="$DATA_DIR/docker-compose.yml"

# Check if node is already running and get current beacon client
CURRENT_BEACON=""
if [ -f "$COMPOSE_FILE" ]; then
    if grep -q "prysm:" "$COMPOSE_FILE"; then
        CURRENT_BEACON="prysm"
    elif grep -q "lighthouse:" "$COMPOSE_FILE"; then
        CURRENT_BEACON="lighthouse"
    fi
fi

# === CHOOSE BEACON CLIENT ===
echo ">>> Choose beacon client to use:"
echo "1) Prysm"
echo "2) Lighthouse"
if [ ! -z "$CURRENT_BEACON" ]; then
    echo -e "\nCurrent beacon client: $CURRENT_BEACON"
fi
read -rp "Enter choice [1 or 2]: " BEACON_CHOICE

if [[ "$BEACON_CHOICE" != "1" && "$BEACON_CHOICE" != "2" ]]; then
  echo "❌ Invalid choice. Exiting."
  exit 1
fi

# Set new beacon client
if [ "$BEACON_CHOICE" = "1" ]; then
  NEW_BEACON="prysm"
  BEACON_VOLUME="$DATA_DIR/prysm"
else
  NEW_BEACON="lighthouse"
  BEACON_VOLUME="$DATA_DIR/lighthouse"
fi

# Clean up old data if beacon client changed
if [ ! -z "$CURRENT_BEACON" ] && [ "$CURRENT_BEACON" != "$NEW_BEACON" ]; then
    echo ">>> Beacon client changed from $CURRENT_BEACON to $NEW_BEACON"
    echo ">>> Cleaning up old data..."
    
    # Stop containers
    cd "$DATA_DIR" && docker compose down || true
    
    # Remove old beacon data
    if [ "$CURRENT_BEACON" = "prysm" ]; then
        rm -rf "$DATA_DIR/prysm"
    elif [ "$CURRENT_BEACON" = "lighthouse" ]; then
        rm -rf "$DATA_DIR/lighthouse"
    fi
fi

# === DEPENDENCY CHECK ===
echo ">>> Checking required dependencies..."
install_if_missing() {
  local cmd="$1"
  local pkg="$2"

  if ! command -v $cmd &> /dev/null; then
    echo "⛔ Missing: $cmd → installing $pkg..."
    sudo apt update
    sudo apt install -y $pkg
  else
    echo "✅ $cmd is already installed."
  fi
}

# Docker check
if ! command -v docker &> /dev/null || ! command -v docker compose &> /dev/null; then
  echo "⛔ Docker or Docker Compose not found. Installing Docker..."

  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y $pkg || true
  done

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo docker run hello-world
  sudo systemctl enable docker && sudo systemctl restart docker
else
  echo "✅ Docker and Docker Compose are already installed."
fi

install_if_missing curl curl
install_if_missing openssl openssl
install_if_missing jq jq

# Create directories
mkdir -p "$GETH_DIR"
mkdir -p "$BEACON_VOLUME"

# === GENERATE JWT SECRET ===
echo ">>> Generating JWT secret..."
openssl rand -hex 32 > "$JWT_FILE"

# === WRITE docker-compose.yml ===
echo ">>> Writing docker-compose.yml..."
cat > "$COMPOSE_FILE" <<EOF
services:
  geth:
    image: ethereum/client-go:stable
    container_name: geth
    restart: unless-stopped
    volumes:
      - $GETH_DIR:/root/.ethereum
      - $JWT_FILE:/root/jwt.hex
    ports:
      - "8545:8545"
      - "30303:30303"
      - "8551:8551"
    command: >
      --sepolia
      --http --http.addr 0.0.0.0 --http.api eth,web3,net,engine
      --authrpc.addr 0.0.0.0 --authrpc.port 8551
      --authrpc.jwtsecret /root/jwt.hex
      --authrpc.vhosts=*
      --http.corsdomain="*"
      --syncmode=snap
      --cache=8192
      --http.vhosts=*
EOF

if [ "$NEW_BEACON" = "prysm" ]; then
  cat >> "$COMPOSE_FILE" <<EOF

  prysm:
    image: gcr.io/prysmaticlabs/prysm/beacon-chain:stable
    container_name: prysm
    restart: unless-stopped
    volumes:
      - $BEACON_VOLUME:/data
      - $JWT_FILE:/root/jwt.hex
    depends_on:
      - geth
    ports:
      - "4000:4000"
      - "3500:3500"
    command: >
      --datadir=/data
      --sepolia
      --execution-endpoint=http://geth:8551
      --jwt-secret=/root/jwt.hex
      --genesis-beacon-api-url=https://lodestar-sepolia.chainsafe.io
      --checkpoint-sync-url=https://sepolia.checkpoint-sync.ethpandaops.io
      --accept-terms-of-use
      --rpc-host=0.0.0.0 --rpc-port=4000
      --grpc-gateway-host=0.0.0.0 --grpc-gateway-port=3500
EOF
else
  cat >> "$COMPOSE_FILE" <<EOF

  lighthouse:
    image: sigp/lighthouse:latest
    container_name: lighthouse
    restart: unless-stopped
    volumes:
      - $BEACON_VOLUME:/root/.lighthouse
      - $JWT_FILE:/root/jwt.hex
    depends_on:
      - geth
    ports:
      - "5052:5052"
      - "9000:9000/tcp"
      - "9000:9000/udp"
    command: >
      lighthouse bn
      --network sepolia
      --execution-endpoint http://geth:8551
      --execution-jwt /root/jwt.hex
      --checkpoint-sync-url=https://sepolia.checkpoint-sync.ethpandaops.io
      --http
      --http-address 0.0.0.0
EOF
fi

# === START DOCKER ===
echo ">>> Starting Sepolia node with $NEW_BEACON..."

# Start Geth first and wait for it to be ready
echo ">>> Starting Geth..."
cd "$DATA_DIR"
docker compose up -d geth

# Wait for Geth to be ready
echo ">>> Waiting for Geth to be ready..."
while true; do
    if curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' > /dev/null; then
        echo ">>> Geth is ready!"
        break
    fi
    echo ">>> Waiting for Geth to start..."
    sleep 5
done

# Start beacon client
echo ">>> Starting $NEW_BEACON beacon client..."
docker compose up -d

# Wait for beacon client to be ready
echo ">>> Waiting for beacon client to be ready..."
if [ "$NEW_BEACON" = "prysm" ]; then
    while true; do
        if curl -s http://localhost:3500/eth/v1/node/syncing > /dev/null; then
            echo ">>> Prysm beacon client is ready!"
            break
        fi
        echo ">>> Waiting for Prysm to start..."
        sleep 5
    done
else
    while true; do
        if curl -s http://localhost:5052/eth/v1/node/syncing > /dev/null; then
            echo ">>> Lighthouse beacon client is ready!"
            break
        fi
        echo ">>> Waiting for Lighthouse to start..."
        sleep 5
    done
fi

echo ">>> Setup completed successfully!"

