#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting Sepolia Node Systemd Setup..."

# Get current user
CURRENT_USER=$(whoami)
NODE_DIR="$HOME/sepolia-node"
LOCAL_BIN="$HOME/.local/bin"

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p "$NODE_DIR/geth"
mkdir -p "$NODE_DIR/prysm"
mkdir -p "$LOCAL_BIN"

# Calculate optimal cache size based on available memory (in MB)
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
CACHE_SIZE=$((TOTAL_MEM / 4))  # Use 25% of total memory for cache
if [ $CACHE_SIZE -gt 4096 ]; then
    CACHE_SIZE=4096  # Cap at 4GB
fi

# Calculate optimal number of peers based on CPU cores
CPU_CORES=$(nproc)
PEER_COUNT=$((CPU_CORES * 2))  # 2 peers per core
if [ $PEER_COUNT -gt 50 ]; then
    PEER_COUNT=50  # Cap at 50 peers
fi

# Install Geth (requires sudo)
echo "📦 Installing Geth..."
if ! command -v geth &> /dev/null; then
    echo "⚠️  Geth not found. Installing..."
    sudo add-apt-repository -y ppa:ethereum/ethereum
    sudo apt-get update
    sudo apt-get install -y ethereum
else
    echo "✅ Geth already installed"
fi

# Install Prysm (no sudo needed)
echo "📦 Installing Prysm..."
if ! command -v prysm &> /dev/null; then
    echo "⚠️  Prysm not found. Installing..."
    # Ensure .local/bin exists and is in PATH
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        echo 'export PATH="$LOCAL_BIN:$PATH"' >> "$HOME/.bashrc"
        export PATH="$LOCAL_BIN:$PATH"
    fi
    
    # Download Prysm
    curl -L https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output "$LOCAL_BIN/prysm"
    chmod +x "$LOCAL_BIN/prysm"
    
    # Verify installation
    if [ -f "$LOCAL_BIN/prysm" ]; then
        echo "✅ Prysm installed successfully"
    else
        echo "❌ Failed to install Prysm"
        exit 1
    fi
else
    echo "✅ Prysm already installed"
fi

# Generate JWT secret
echo "🔑 Generating JWT secret..."
openssl rand -hex 32 > "$NODE_DIR/jwt.hex"
chmod 600 "$NODE_DIR/jwt.hex"

# Create Geth service file with optimized parameters
echo "📝 Creating Geth service file..."
cat > "$NODE_DIR/sepolia-geth.service" << EOF
[Unit]
Description=Sepolia Geth Node
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$NODE_DIR
ExecStart=/usr/bin/geth --sepolia \\
    --http --http.addr 0.0.0.0 --http.port 8545 \\
    --http.api eth,net,engine,debug,txpool,web3 \\
    --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.vhosts "*" \\
    --datadir $NODE_DIR/geth
ExecStop=/usr/bin/pkill geth
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Prysm service file with optimized parameters
echo "📝 Creating Prysm service file..."
cat > "$NODE_DIR/sepolia-prysm.service" << EOF
[Unit]
Description=Sepolia Prysm Beacon Node
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$NODE_DIR
ExecStart=$HOME/.local/bin/prysm beacon-chain \\
    --sepolia \\
    --datadir=$NODE_DIR/prysm \\
    --execution-endpoint=http://localhost:8551 \\
    --jwt-secret=$NODE_DIR/jwt.hex \\
    --checkpoint-sync-url=https://sync-sepolia.beaconcha.in
ExecStop=/usr/bin/pkill beacon-chain
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Copy service files to systemd directory (requires sudo)
echo "📝 Installing service files..."
sudo cp "$NODE_DIR/sepolia-geth.service" /etc/systemd/system/
sudo cp "$NODE_DIR/sepolia-prysm.service" /etc/systemd/system/

# Reload systemd and enable services (requires sudo)
echo "🔄 Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable sepolia-geth
sudo systemctl enable sepolia-prysm

# Start services automatically
echo "🚀 Starting services..."
sudo systemctl start sepolia-geth
sudo systemctl start sepolia-prysm

# Wait a moment for services to start
echo "⏳ Waiting for services to start..."
sleep 5

# Check service status
echo "📊 Checking service status..."
echo "Geth status:"
sudo systemctl status sepolia-geth --no-pager
echo ""
echo "Prysm status:"
sudo systemctl status sepolia-prysm --no-pager

echo "✅ Setup complete! Services are now running."
echo ""
echo "📊 Monitoring endpoints:"
echo "- Geth metrics: http://localhost:6060/debug/metrics"
echo "- Prysm metrics: http://localhost:8080/metrics"
echo ""
echo "📝 To check logs:"
echo "sudo journalctl -u sepolia-geth -f"
echo "sudo journalctl -u sepolia-prysm -f"
echo ""
echo "Note: Only systemd operations require sudo. All other operations are done as your user." 