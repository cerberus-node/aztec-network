# 📘 Guide: Auto Setup Sepolia RPC + Beacon Node for Sequencer

This guide walks you through setting up a Sepolia Ethereum node (Geth + Lighthouse) using an automated script. Ideal for running a sequencer backend that requires both RPC and Beacon API access.

---

## ⚙️ System Requirements

- **Disk:** 1TB+ SSD
- **RAM:** 16GB+
- **OS:** Ubuntu 20.04+ (or compatible Linux distro)
- **Tools:** Docker, Docker Compose, `curl`, `openssl`

---

## 🚀 Setup Instructions

### Execute the following one-liner to download and run the installation script

```bash
curl -sL https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/auto-setup-sepolia.sh -o auto-setup-sepolia.sh && chmod +x auto-setup-sepolia.sh && bash auto-setup-sepolia.sh

```
This will:
- Create folder structure at `~/sepolia-node`
- Generate a valid `jwt.hex`
- Write a production-ready `docker-compose.yml`
- Launch Geth + Lighthouse for Sepolia

---

## 📦 (Optional) Docker Snapshot Restore

⚠️ Before Using Snapshots

Before extracting snapshot archives, stop your node:

#### For Docker:
```bash
cd ~/sepolia-node
docker compose down
```

You can use a snapshot to significantly reduce sync time. Example for Geth:

```bash
sudo apt update && sudo apt install -y lz4
rm -rf ~/sepolia-node/geth
mkdir -p ~/sepolia-node/geth

curl -L https://snapshots.publicnode.com/ethereum-sepolia-geth-part-8320240.tar.lz4 | lz4 -d | tar -x -C ~/sepolia-node/geth
```

For Lighthouse:
```bash
curl -L https://snapshots.publicnode.com/ethereum-sepolia-lighthouse-7619325.tar.lz4 -o lighthouse-snapshot.tar.lz4
lz4 -d lighthouse-snapshot.tar.lz4 | tar -x -C ~/sepolia-node/lighthouse
```

For Prysm:
```bash
sudo apt update && sudo apt install -y lz4
rm -rf ~/sepolia-node/prysm
mkdir -p ~/sepolia-node/prysm

curl -L https://snapshots.publicnode.com/ethereum-sepolia-prysm-7619477.tar.lz4 | lz4 -d | tar -x -C ~/sepolia-node/prysm

```
---

## ✅ Verify

### Check sync progress:
```bash
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
```

### Check Beacon API health:
For Lighthouse:
```bash
curl -s http://localhost:5052/eth/v1/node/syncing | jq
```

For Prysm:
```bash
curl -s http://localhost:3500/eth/v1/node/syncing | jq
```
---

## 🧠 Notes

- The sync process may take several hours to complete.
- Ensure enough disk space (1TB+) is available.
- Once `eth_syncing` returns `false`, your RPC is fully operational.

---

## 🔄 Restart / Monitor

```bash
cd ~/sepolia-node

docker compose logs -f geth

docker compose logs -f lighthouse
```

To restart:
```bash
docker compose restart
```

To stop:
```bash
docker compose down
```

---

## 🛠️ Systemd Setup (Binary Installation)

To run the Sepolia node as systemd services using binary installations:

### 1. Install Binaries

#### Install Geth
```bash
# Add Ethereum repository
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt-get update
sudo apt-get install -y ethereum
```

#### Install Prysm
```bash
# Create local bin directory
mkdir -p ~/.local/bin

# Download Prysm script
curl -L https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output ~/.local/bin/prysm
chmod +x ~/.local/bin/prysm

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 2. Create Directory Structure
```bash
# Create node directories
mkdir -p ~/sepolia-node/geth
mkdir -p ~/sepolia-node/prysm
```

### 3. Generate JWT Secret
```bash
# Generate JWT secret
openssl rand -hex 32 > ~/sepolia-node/jwt.hex
chmod 600 ~/sepolia-node/jwt.hex
```




### 📦 (Optional) Systemd Snapshot Restore

⚠️ Before Using Snapshots

Before extracting snapshot archives, stop your node:

#### For Systemd:
```bash
sudo systemctl stop sepolia-geth
sudo systemctl stop sepolia-prysm
```

You can use a snapshot to speed up sync:

```bash
# Geth
curl -L https://snapshots.publicnode.com/ethereum-sepolia-geth-part-8320240.tar.lz4 -o geth-snapshot.tar.lz4
lz4 -d geth-snapshot.tar.lz4 | tar -x -C ~/sepolia-node/geth

# Prysm
curl -L https://snapshots.publicnode.com/ethereum-sepolia-prysm-7619477.tar.lz4 -o prysm-snapshot.tar.lz4
lz4 -d prysm-snapshot.tar.lz4 | tar -x -C ~/sepolia-node/prysm
```

### 4. Create Service Files

Create Geth service file:
```ini
sudo tee /etc/systemd/system/sepolia-geth.service > /dev/null <<EOF
[Unit]
Description=Sepolia Geth Node
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$HOME/sepolia-node
ExecStart=/usr/bin/geth --sepolia \\
  --http --http.addr 0.0.0.0 --http.port 8545 \\
  --http.api eth,net,engine,debug,txpool,web3 \\
  --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.vhosts "*" \\
  --authrpc.jwtsecret=$HOME/sepolia-node/jwt.hex \\
  --datadir $HOME/sepolia-node/geth \\
  --syncmode snap \\
  --cache 4096 \\
  --metrics --pprof --pprof.addr 0.0.0.0 --pprof.port 6060
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 🔄 Reload systemd
sudo systemctl daemon-reload

```

Create Prysm service file:

```ini
sudo tee /etc/systemd/system/sepolia-prysm.service > /dev/null <<EOF
[Unit]
Description=Sepolia Prysm Beacon Node
After=network.target sepolia-geth.service
Requires=sepolia-geth.service

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$HOME/sepolia-node
ExecStart=$HOME/.local/bin/prysm beacon-chain \\
  --sepolia \\
  --datadir=$HOME/sepolia-node/prysm \\
  --execution-endpoint=http://localhost:8551 \\
  --jwt-secret=$HOME/sepolia-node/jwt.hex \\
  --genesis-beacon-api-url=https://lodestar-sepolia.chainsafe.io \\
  --checkpoint-sync-url=https://sepolia.checkpoint-sync.ethpandaops.io \\
  --accept-terms-of-use \\
  --suggested-fee-recipient=0x0000000000000000000000000000000000000000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 🔄 Reload systemd
sudo systemctl daemon-reload

```

### 5. Enable and Start Services
```bash
# Reload systemd
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable sepolia-geth
sudo systemctl enable sepolia-prysm

# Start services
sudo systemctl start sepolia-geth
sleep 10  # Wait for Geth to initialize
sudo systemctl start sepolia-prysm
```

### 6. Monitor Services
```bash
# Check service status
sudo systemctl status sepolia-geth
sudo systemctl status sepolia-prysm

# View logs
sudo journalctl -u sepolia-geth -f
sudo journalctl -u sepolia-prysm -f
```

Note:
- Replace `$USER` with your actual username or use the full path to your home directory
- The services are configured to restart automatically if they crash
- Prysm depends on Geth and will start after Geth is running
- Checkpoint sync is enabled for faster initial sync
- Metrics and profiling are enabled for monitoring

## 🔐 (Optional) Open Firewall Ports

If you use `ufw` or another firewall, run:

```bash
sudo ufw allow 8545/tcp    # Geth JSON-RPC
sudo ufw allow 8551/tcp    # Engine API
sudo ufw allow 30303/tcp   # Geth P2P TCP
sudo ufw allow 30303/udp   # Geth P2P UDP

sudo ufw allow 5052/tcp    # Beacon API
sudo ufw allow 9000/tcp    # Lighthouse P2P TCP
sudo ufw allow 9000/udp    # Lighthouse P2P UDP

sudo ufw reload
```

Once opened, you can access RPC or Beacon API from other machines via:
- Geth RPC: `http://<your-ip>:8545`
- Beacon API: `http://<your-ip>:5052`

---
## 🗑️ Remove Node
```bash
cd ~/sepolia-node

docker compose down

rm -rf ~/sepolia-node
```
