#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting Sepolia Node Systemd Setup..."

# Get current user
CURRENT_USER=$(whoami)
NODE_DIR="$HOME/sepolia-node"
LOCAL_BIN="$HOME/.local/bin"
GETH_BIN=$(command -v geth || echo "/usr/bin/geth")
PRYSM_BIN="$LOCAL_BIN/prysm"

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p "$NODE_DIR/geth"
mkdir -p "$NODE_DIR/prysm"
mkdir -p "$LOCAL_BIN"

# Calculate optimal cache size
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
CACHE_SIZE=$((TOTAL_MEM / 4))
[ $CACHE_SIZE -gt 4096 ] && CACHE_SIZE=4096

# Calculate peer count
CPU_CORES=$(nproc)
PEER_COUNT=$((CPU_CORES * 2))
[ $PEER_COUNT -gt 50 ] && PEER_COUNT=50

# Install Geth
if ! command -v geth &> /dev/null; then
  echo "⚠️  Geth not found. Installing..."
  sudo add-apt-repository -y ppa:ethereum/ethereum
  sudo apt-get update
  sudo apt-get install -y ethereum
else
  echo "✅ Geth already installed"
fi

# Install Prysm
if [ ! -f "$PRYSM_BIN" ]; then
  echo "⚠️  Prysm not found. Installing..."
  export PATH="$LOCAL_BIN:$PATH"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  curl -L https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output "$PRYSM_BIN"
  chmod +x "$PRYSM_BIN"
else
  echo "✅ Prysm already installed"
fi

# Generate JWT secret
echo "🔑 Generating JWT secret..."
openssl rand -hex 32 > "$NODE_DIR/jwt.hex"
chmod 600 "$NODE_DIR/jwt.hex"

# Create Geth systemd service
cat > "$NODE_DIR/sepolia-geth.service" <<EOF
[Unit]
Description=Sepolia Geth Node
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$NODE_DIR
ExecStart=$GETH_BIN --sepolia \\
  --http --http.addr 0.0.0.0 --http.port 8545 \\
  --http.api eth,net,engine,debug,txpool,web3 \\
  --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.vhosts "*" \\
  --authrpc.jwtsecret=$NODE_DIR/jwt.hex \\
  --datadir $NODE_DIR/geth \\
  --syncmode snap \\
  --cache $CACHE_SIZE \\
  --metrics --pprof --pprof.addr 0.0.0.0 --pprof.port 6060
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Prysm systemd service
cat > "$NODE_DIR/sepolia-prysm.service" <<EOF
[Unit]
Description=Sepolia Prysm Beacon Node
After=network.target sepolia-geth.service
Requires=sepolia-geth.service

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$NODE_DIR
ExecStart=$PRYSM_BIN beacon-chain \\
  --sepolia \\
  --datadir=$NODE_DIR/prysm \\
  --execution-endpoint=http://localhost:8551 \\
  --jwt-secret=$NODE_DIR/jwt.hex \\
  --genesis-beacon-api-url=https://lodestar-sepolia.chainsafe.io \\
  --checkpoint-sync-url=https://sepolia.checkpoint-sync.ethpandaops.io \\
  --accept-terms-of-use \\
  --suggested-fee-recipient=0x0000000000000000000000000000000000000000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Copy service files
sudo cp "$NODE_DIR/sepolia-geth.service" /etc/systemd/system/
sudo cp "$NODE_DIR/sepolia-prysm.service" /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable sepolia-geth
sudo systemctl enable sepolia-prysm

# Start services
echo "🚀 Starting services..."
sudo systemctl start sepolia-geth
sleep 10
sudo systemctl start sepolia-prysm

# Status
echo "📊 Checking status..."
sudo systemctl status sepolia-geth --no-pager
sudo systemctl status sepolia-prysm --no-pager

echo "✅ Setup complete! Use journalctl to monitor logs."
echo "sudo journalctl -u sepolia-geth -f"
echo "sudo journalctl -u sepolia-prysm -f"
