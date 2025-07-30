#!/bin/bash

set -e

INSTALL_DIR="aztec-sequencer"
echo "📁 Creating project directory: $INSTALL_DIR"
mkdir -p $INSTALL_DIR && cd $INSTALL_DIR

read -p "🔗 Enter Ethereum RPC URL (e.g. https://sepolia.rpc.url): " ETHEREUM_HOSTS
read -p "🔗 Enter Beacon RPC URL (e.g. https://beacon.rpc.url): " L1_CONSENSUS_HOST_URLS
read -p "🔑 Enter your Ethereum Private Key (0x...): " VALIDATOR_PRIVATE_KEYS
read -p "🏦 Enter your Ethereum Address (0x...): " VALIDATOR_ADDRESS

# Optional: SEQ_PUBLISHER_PRIVATE_KEY
read -p "🔑 Enter SEQ_PUBLISHER_PRIVATE_KEY (optional, press Enter to skip): " SEQ_PUBLISHER_PRIVATE_KEY

P2P_IP=$(curl -s ipv4.icanhazip.com)
echo "🌍 Detected Public IP: $P2P_IP"

# Step 0: Install Dependencies
echo "🔧 Installing system dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf \
  tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang \
  bsdmainutils ncdu unzip ca-certificates gnupg

# Step 1: Install Docker
echo "🐳 Installing Docker..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done
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

# Step 2: Install Aztec CLI Tools
echo "🧰 Installing Aztec CLI tools..."
bash -i <(curl -s https://install.aztec.network)
echo 'export PATH="$PATH:/root/.aztec/bin"' >> ~/.bashrc && source ~/.bashrc

# Create .env file
echo "📄 Creating .env file..."
cat <<EOF > .env
ETHEREUM_HOSTS=$ETHEREUM_HOSTS
L1_CONSENSUS_HOST_URLS=$L1_CONSENSUS_HOST_URLS
VALIDATOR_PRIVATE_KEYS=$VALIDATOR_PRIVATE_KEYS
VALIDATOR_ADDRESS=$VALIDATOR_ADDRESS
P2P_IP=$P2P_IP
${SEQ_PUBLISHER_PRIVATE_KEY:+SEQ_PUBLISHER_PRIVATE_KEY=$SEQ_PUBLISHER_PRIVATE_KEY}
EOF

echo "✅ .env file created."

# Create docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  aztec-node:
    container_name: aztec-sequencer
    image: aztecprotocol/aztec:1.2.0
    restart: unless-stopped
    environment:
      ETHEREUM_HOSTS: \${ETHEREUM_HOSTS}
      L1_CONSENSUS_HOST_URLS: \${L1_CONSENSUS_HOST_URLS}
      VALIDATOR_PRIVATE_KEYS: \${VALIDATOR_PRIVATE_KEYS}
      P2P_IP: \${P2P_IP}
      LOG_LEVEL: debug
      SEQ_PUBLISHER_PRIVATE_KEY: \${SEQ_PUBLISHER_PRIVATE_KEY:-}
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - ./data:/root/.aztec
    network_mode: host

volumes:
  data:
EOF

echo "✅ docker-compose.yml created."

echo "🚀 Starting Aztec node..."
docker compose --env-file .env up -d
