#!/bin/bash

# 🚀 Auto Setup Sepolia Geth + Beacon (Prysm or Lighthouse) for Aztec Sequencer
# Assumes system has at least 1TB NVMe, 16GB RAM

set -e

# === CHOOSE BEACON CLIENT ===
echo ">>> Choose beacon client to use:"
echo "1) Prysm"
echo "2) Lighthouse"
read -rp "Enter choice [1 or 2]: " BEACON_CHOICE

if [[ "$BEACON_CHOICE" != "1" && "$BEACON_CHOICE" != "2" ]]; then
  echo "❌ Invalid choice. Exiting."
  exit 1
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

# === CONFIG ===
DATA_DIR="$HOME/sepolia-node"
GETH_DIR="$DATA_DIR/geth"
JWT_FILE="$DATA_DIR/jwt.hex"
COMPOSE_FILE="$DATA_DIR/docker-compose.yml"
mkdir -p "$GETH_DIR"

if [ "$BEACON_CHOICE" = "1" ]; then
  BEACON="prysm"
  BEACON_VOLUME="$DATA_DIR/prysm"
else
  BEACON="lighthouse"
  BEACON_VOLUME="$DATA_DIR/lighthouse"
fi
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

if [ "$BEACON" = "prysm" ]; then
  cat >> "$COMPOSE_FILE" <<EOF

  prysm:
    image: gcr.io/prysmaticlabs/prysm/beacon-chain:stable
    container_name: prysm
    restart: unless-stopped
    volumes:
      - $BEACON_VOLUME:/data
      - $JWT_FILE:/data/jwt.hex
    depends_on:
      - geth
    ports:
      - "4000:4000"
      - "3500:3500"
    command: >
      --datadir=/data
      --sepolia
      --execution-endpoint=http://geth:8551
      --jwt-secret=/data/jwt.hex
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
echo ">>> Starting Sepolia node with $BEACON..."
cd "$DATA_DIR"
docker compose up -d

# Get public IP
PUBLIC_IP=$(curl -s ipv4.icanhazip.com)

echo -e "\n${GREEN}=== 🚀 Node Setup Complete ===${NC}"
echo -e "\n${YELLOW}=== 📡 Available Endpoints ===${NC}"

# Display Geth (RPC) endpoints
echo -e "\n${BLUE}Geth (RPC) Endpoints:${NC}"
echo -e "  HTTP:     http://localhost:8545"
echo -e "  WebSocket: ws://localhost:8545"
echo -e "  Auth RPC:  http://localhost:8551"
echo -e "\n  Public HTTP:     http://${PUBLIC_IP}:8545"
echo -e "  Public WebSocket: ws://${PUBLIC_IP}:8545"
echo -e "  Public Auth RPC:  http://${PUBLIC_IP}:8551"

# Display Beacon endpoints based on client
if [ "$BEACON" = "prysm" ]; then
    echo -e "\n${BLUE}Prysm Beacon Endpoints:${NC}"
    echo -e "  HTTP:     http://localhost:4000"
    echo -e "  gRPC:     localhost:3500"
    echo -e "\n  Public HTTP: http://${PUBLIC_IP}:4000"
    echo -e "  Public gRPC: ${PUBLIC_IP}:3500"
else
    echo -e "\n${BLUE}Lighthouse Beacon Endpoints:${NC}"
    echo -e "  HTTP:     http://localhost:5052"
    echo -e "  P2P:      localhost:9000 (TCP/UDP)"
    echo -e "\n  Public HTTP: http://${PUBLIC_IP}:5052"
    echo -e "  Public P2P:  ${PUBLIC_IP}:9000 (TCP/UDP)"
fi

echo -e "\n${YELLOW}=== 🔧 Testing Endpoints ===${NC}"
echo -e "Testing RPC endpoint..."
curl -s http://localhost:8545 -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | jq

echo -e "\nTesting Beacon endpoint..."
if [ "$BEACON" = "prysm" ]; then
    curl -s http://localhost:4000/eth/v1/node/health | jq
else
    curl -s http://localhost:5052/eth/v1/node/health | jq
fi

echo -e "\n${YELLOW}=== 📝 Usage Examples ===${NC}"
echo -e "${BLUE}1. Using with MetaMask:${NC}"
echo -e "   RPC URL: http://${PUBLIC_IP}:8545"
echo -e "   Chain ID: 11155111 (Sepolia)"

echo -e "\n${BLUE}2. Using with curl:${NC}"
echo -e "   # Get latest block"
echo -e "   curl -s http://localhost:8545 -H 'Content-Type: application/json' \\"
echo -e "     -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' | jq"

echo -e "\n${BLUE}3. Using with Web3.js:${NC}"
echo -e "   const web3 = new Web3('http://${PUBLIC_IP}:8545');"

echo -e "\n${BLUE}4. Using with ethers.js:${NC}"
echo -e "   const provider = new ethers.providers.JsonRpcProvider('http://${PUBLIC_IP}:8545');"

echo -e "\n${YELLOW}=== ⚠️ Important Notes ===${NC}"
echo -e "1. Check logs with: docker logs -f [container_name]"
echo -e "2. Monitor sync status with the test commands above"
echo -e "3. Make sure ports are open in your firewall if accessing remotely"

echo -e "\n${GREEN}✅ Setup complete! Your node is ready to use.${NC}"