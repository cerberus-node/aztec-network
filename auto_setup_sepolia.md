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
  --metrics.port 6060
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
ExecStart=/usr/local/bin/prysm beacon-chain --sepolia --datadir=/home/$USER/sepolia-node/prysm --execution-endpoint=http://localhost:8551 --jwt-secret=/home/$USER/sepolia-node/jwt.hex
ExecStop=/usr/bin/pkill beacon-chain
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 3. Create JWT Secret
```bash
# Generate JWT secret
openssl rand -hex 32 > /home/$USER/sepolia-node/jwt.hex
chmod 600 /home/$USER/sepolia-node/jwt.hex
```

### 4. Enable and start the services

```bash
# Reload systemd to recognize new services
sudo systemctl daemon-reload

# Enable services to start on boot
sudo systemctl enable sepolia-geth
sudo systemctl enable sepolia-prysm

# Start the services
sudo systemctl start sepolia-geth
sudo systemctl start sepolia-prysm
```

### 5. Check service status

```bash
# Check Geth status
sudo systemctl status sepolia-geth

# Check Prysm status
sudo systemctl status sepolia-prysm
```

### 6. View logs

```bash
# View Geth logs
sudo journalctl -u sepolia-geth -f

# View Prysm logs
sudo journalctl -u sepolia-prysm -f
```

### 7. Common commands

```bash
# Stop services
sudo systemctl stop sepolia-geth
sudo systemctl stop sepolia-prysm

# Restart services
sudo systemctl restart sepolia-geth
sudo systemctl restart sepolia-prysm

# Disable services from starting on boot
sudo systemctl disable sepolia-geth
sudo systemctl disable sepolia-prysm
```

Note: 
- Replace `$USER` in the service files with your actual username or use the full path to your home directory
- Make sure to create the necessary directories before starting the services
- The JWT secret file is required for the Engine API authentication between Geth and Prysm

---

## 🚀 Quick Setup with Systemd Script

For a quick and automated setup of the Sepolia node using systemd services, you can use our auto-setup script:

### 1. Download and run the script

```bash
curl -sL https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/auto-setup-sepolia-systemd.sh -o auto-setup-sepolia-systemd.sh && chmod +x auto-setup-sepolia-systemd.sh && sudo ./auto-setup-sepolia-systemd.sh
```

This script will:
- Install Geth and Prysm binaries
- Create necessary directory structure
- Generate JWT secret
- Create and configure systemd services
- Set proper permissions
- Enable services to start on boot

### 2. Start the services

After the script completes, start the services:

```bash
sudo systemctl start sepolia-geth
sudo systemctl start sepolia-prysm
```

### 3. Verify the setup

Check the status of your services:

```bash
sudo systemctl status sepolia-geth
sudo systemctl status sepolia-prysm
```

The script handles all the manual steps described in the previous section automatically. If you prefer to understand and customize each step, please refer to the manual setup instructions above.

Note: The script requires sudo privileges as it needs to:
- Install system packages
- Create systemd service files
- Set up proper permissions

---

## 🗑️ Remove Node

### 1. Stop and disable services
```bash
# Stop services
sudo systemctl stop sepolia-geth
sudo systemctl stop sepolia-prysm

# Disable services from starting on boot
sudo systemctl disable sepolia-geth
sudo systemctl disable sepolia-prysm
```

### 2. Remove service files
```bash
# Remove systemd service files
sudo rm /etc/systemd/system/sepolia-geth.service
sudo rm /etc/systemd/system/sepolia-prysm.service

# Reload systemd
sudo systemctl daemon-reload
```

### 3. Remove binaries
```bash
# Remove Geth
sudo apt-get remove -y ethereum
sudo apt-get autoremove -y

# Remove Prysm
sudo rm /usr/local/bin/prysm
```

### 4. Remove data
```bash
# Remove node data directory
rm -rf ~/sepolia-node
```

### 5. Clean up repositories
```bash
# Remove Ethereum repository
sudo add-apt-repository --remove ppa:ethereum/ethereum
sudo apt-get update
```

---

Built with ❤️ for L2 sequencers.
