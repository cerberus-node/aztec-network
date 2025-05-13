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

## ✅ Verify

### Check sync progress:
```bash
curl -s -X POST http://localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
```

### Check Beacon API health:
```bash
curl -s http://localhost:5052/eth/v1/node/syncing | jq
```

---

## 🧠 Notes

- The sync process may take several hours to complete.
- Ensure enough disk space (1TB+) is available.
- Once `eth_syncing` returns `false`, your RPC is fully operational.
- You can now connect your L2 sequencer to `localhost:8551` (Engine API).

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
# Download Prysm script
curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output prysm.sh
chmod +x prysm.sh
sudo mv prysm.sh /usr/local/bin/prysm

# Verify installation
prysm --version
```

### 2. Create systemd service files

Create Geth service file:
```bash
sudo nano /etc/systemd/system/sepolia-geth.service
```

Add the following content:
```ini
[Unit]
Description=Sepolia Geth Node
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/sepolia-node
ExecStart=/usr/bin/geth --sepolia \
  --http \
  --http.addr 0.0.0.0 \
  --http.port 8545 \
  --http.api eth,net,engine,debug \
  --http.corsdomain "*" \
  --authrpc.addr 0.0.0.0 \
  --authrpc.port 8551 \
  --authrpc.vhosts "*" \
  --datadir /home/$USER/sepolia-node/geth \
  --cache 4096 \
  --maxpeers 50 \
  --syncmode snap \
  --metrics \
  --metrics.addr 0.0.0.0 \
  --metrics.port 6060 \
  --authrpc.jwtsecret=/home/$USER/sepolia-node/jwt.hex
ExecStop=/usr/bin/pkill geth
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Create Prysm service file:
```bash
sudo nano /etc/systemd/system/sepolia-prysm.service
```

Add the following content:
```ini
[Unit]
Description=Sepolia Prysm Beacon Node
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/sepolia-node
ExecStart=/usr/local/bin/prysm beacon-chain --sepolia \
  --datadir=/home/$USER/sepolia-node/prysm \
  --execution-endpoint=http://localhost:8551 \
  --jwt-secret=/home/$USER/sepolia-node/jwt.hex \
  --checkpoint-sync-url=https://sepolia.checkpoint-sync.ethpandaops.io
ExecStop=/usr/bin/pkill beacon-chain
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 3. Create JWT Secret
```bash
# Create directory if it doesn't exist
mkdir -p /home/$USER/sepolia-node

# Generate JWT secret
openssl rand -hex 32 > /home/$USER/sepolia-node/jwt.hex
chmod 600 /home/$USER/sepolia-node/jwt.hex
```

### 4. Enable and start the services

```