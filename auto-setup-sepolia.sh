#!/bin/bash

# 🚀 Auto Setup Sepolia Geth + Beacon (Prysm or Lighthouse) for Aztec Sequencer

set -e

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1; then
        echo "❌ Port $port is already in use"
        return 1
    fi
    return 0
}

# === CHECK PORTS ===
echo ">>> Checking required ports..."
for port in 80 8545 30303 8551 4000 3500 5052 9000; do
    if ! check_port $port; then
        echo "❌ Please free up port $port before continuing"
        exit 1
    fi
done

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

# Create directories
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
chmod 600 "$JWT_FILE"  # Secure JWT file permissions

# === WRITE docker-compose.yml ===
echo ">>> Writing docker-compose.yml..."
cat > "$COMPOSE_FILE" <<EOF
services:
  haproxy:
    image: haproxy:2.8
    container_name: haproxy
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - geth
      - ${BEACON}
    networks:
      - node_network

  geth:
    image: ethereum/client-go:stable
    container_name: geth
    restart: unless-stopped
    user: "\${UID}:\${GID}"
    volumes:
      - $GETH_DIR:/root/.ethereum
      - $JWT_FILE:/root/jwt.hex:ro
    expose:
      - "8545"
      - "30303"
      - "8551"
    networks:
      - node_network
    command: >
      --sepolia
      --http --http.addr 0.0.0.0 --http.api eth,web3,net,engine
      --authrpc.addr 0.0.0.0 --authrpc.port 8551
      --authrpc.jwtsecret /root/jwt.hex
      --authrpc.vhosts=localhost
      --http.corsdomain="http://localhost:*"
      --syncmode=snap
      --cache=8192
EOF

if [ "$BEACON" = "prysm" ]; then
    cat >> "$COMPOSE_FILE" <<EOF
  prysm:
    image: gcr.io/prysmaticlabs/prysm/beacon-chain:stable
    container_name: prysm
    restart: unless-stopped
    user: "\${UID}:\${GID}"
    volumes:
      - $BEACON_VOLUME:/data
      - $JWT_FILE:/data/jwt.hex:ro
    depends_on:
      - geth
    expose:
      - "4000"
      - "3500"
    networks:
      - node_network
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
    user: "\${UID}:\${GID}"
    volumes:
      - $BEACON_VOLUME:/root/.lighthouse
      - $JWT_FILE:/root/jwt.hex:ro
    depends_on:
      - geth
    expose:
      - "5052"
      - "9000"
    networks:
      - node_network
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

cat >> "$COMPOSE_FILE" <<EOF

networks:
  node_network:
    driver: bridge
EOF

# Create HAProxy configuration
echo ">>> Creating HAProxy configuration..."
cat > "$DATA_DIR/haproxy.cfg" <<EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if TRUE

frontend geth_http
    bind *:80
    mode http
    option httplog
    acl is_geth path_beg /rpc
    use_backend geth_http if is_geth

frontend geth_ws
    bind *:80
    mode http
    option httplog
    acl is_ws hdr(Upgrade) -i WebSocket
    use_backend geth_ws if is_ws

frontend beacon_http
    bind *:80
    mode http
    option httplog
    acl is_beacon path_beg /beacon
    use_backend beacon_http if is_beacon

backend geth_http
    mode http
    server geth1 geth:8545 check

backend geth_ws
    mode http
    server geth1 geth:8545 check

backend beacon_http
    mode http
    server beacon1 ${BEACON}:${BEACON == "prysm" ? "4000" : "5052"} check
EOF

# === START DOCKER ===
echo ">>> Starting Sepolia node with $BEACON..."
cd "$DATA_DIR"

# Validate checkpoint sync URLs
echo ">>> Validating checkpoint sync URLs..."
if ! curl -s -f "https://sepolia.checkpoint-sync.ethpandaops.io/eth/v1/beacon/states/finalized" > /dev/null; then
    echo "❌ Checkpoint sync URL is not accessible"
    exit 1
fi

# Start services with error handling
if ! docker compose up -d; then
    echo "❌ Failed to start services"
    exit 1
fi

# Wait for services to be healthy
echo ">>> Waiting for services to be healthy..."
sleep 10

# Check if services are running
if ! docker compose ps | grep -q "Up"; then
    echo "❌ Services failed to start properly"
    docker compose logs
    exit 1
fi

# Get public IP
PUBLIC_IP=$(curl -s ipv4.icanhazip.com)

echo -e "\n${GREEN}=== 🚀 Node Setup Complete ===${NC}"
echo -e "\n${YELLOW}=== 📡 Available Endpoints ===${NC}"
echo -e "${BLUE}Local Endpoints:${NC}"
echo -e "  RPC HTTP:    http://localhost/rpc"
echo -e "  RPC WebSocket: ws://localhost/rpc"
echo -e "  Beacon HTTP: http://localhost/beacon"
echo -e "  Stats Page:   http://localhost:8404/stats"

echo -e "\n${BLUE}Public Endpoints:${NC}"
echo -e "  RPC HTTP:    http://${PUBLIC_IP}/rpc"
echo -e "  RPC WebSocket: ws://${PUBLIC_IP}/rpc"
echo -e "  Beacon HTTP: http://${PUBLIC_IP}/beacon"
echo -e "  Stats Page:   http://${PUBLIC_IP}:8404/stats"

echo -e "\n${YELLOW}=== 🔧 Testing Endpoints ===${NC}"
echo -e "Testing RPC endpoint..."
curl -s http://localhost/rpc -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | jq

echo -e "\nTesting Beacon endpoint..."
curl -s http://localhost/beacon/eth/v1/node/health | jq

echo -e "\n${YELLOW}=== 📝 Usage Examples ===${NC}"
echo -e "${BLUE}1. Using with MetaMask:${NC}"
echo -e "   RPC URL: http://${PUBLIC_IP}/rpc"
echo -e "   Chain ID: 11155111 (Sepolia)"

echo -e "\n${BLUE}2. Using with curl:${NC}"
echo -e "   # Get latest block"
echo -e "   curl -s http://localhost/rpc -H 'Content-Type: application/json' \\"
echo -e "     -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' | jq"

echo -e "\n${BLUE}3. Using with Web3.js:${NC}"
echo -e "   const web3 = new Web3('http://${PUBLIC_IP}/rpc');"

echo -e "\n${BLUE}4. Using with ethers.js:${NC}"
echo -e "   const provider = new ethers.providers.JsonRpcProvider('http://${PUBLIC_IP}/rpc');"

echo -e "\n${YELLOW}=== ⚠️ Important Notes ===${NC}"
echo -e "1. Monitor your node at: http://localhost:8404/stats"
echo -e "2. Check logs with: docker logs -f [container_name]"

echo -e "\n${GREEN}✅ Setup complete! Your node is ready to use.${NC}"
