# 🚀 Aztec Sequencer Node Setup – Comprehensive Guide

This guide walks you through setting up a **Sequencer Node** on the Aztec Network testnet and earning the `Apprentice` role.

---

## 🔍 Overview of Node Roles

* **Sequencer**: Proposes and validates blocks, and participates in governance voting. Operates the rollup, contributes to block production, and ensures data availability.

---

## 📜 Role Requirements

To understand the full range of node roles and their requirements, visit the Aztec Discord:
👉 [Role Details Here](https://discord.com/channels/1144692727120937080/1367196595866828982/1367323893324582954)

---

## 💻 System Requirements

| Component | Recommended           | Minimum for VPS       |
| --------- | --------------------- | --------------------- |
| CPU       | 8 cores               | 4 cores               |
| RAM       | 16 GB                 | 8 GB                  |
| Storage   | 100 GB+ SSD           | 50 GB SSD             |
| OS        | Ubuntu 22.04 or 24.04 | Ubuntu 22.04 or later |

---

## ⚙️ Setup Methods

Aztec provides two ways to set up your Sequencer Node:

### 🔹 Option 1: ⚡ One-Line Quick Setup *(Best for new VPS users)*

Run this command to perform a full automated installation:

```bash
bash <(curl -s https://raw.githubusercontent.com/cerberus-node/aztec-network/main/aztec-sequencer-install.sh)
```

✅ What this script does:

* Installs all dependencies
* Installs Docker
* Pulls Aztec image
* Creates `.env` and mounts Docker volume
* Starts the sequencer container

> ⚠️ Use only on fresh Ubuntu 22.04/24.04 servers with sudo access.
---
### 🔹 Option 2: 🛠️ Manual Setup *(Advanced/Custom setup)*

Follow this path if you want full control over configurations and execution.

---

## ⚙️ Step 1: Install System Dependencies

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli \
libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip -y
```

### Install Docker:

```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo docker run hello-world
sudo systemctl enable docker && sudo systemctl restart docker
```

---

## 🪛 Step 2: Install Aztec CLI Tools

```bash
bash -i <(curl -s https://install.aztec.network)
```

When prompted:

```
The directory /root/.aztec/bin is not in your PATH.
Add it to /root/.bash_profile to make the aztec binaries accessible? (y/n)
```

Choose `y`, or run manually:

```bash
echo 'export PATH="$PATH:/root/.aztec/bin"' >> ~/.bashrc && source ~/.bashrc
```

Verify:

```bash
aztec
```

---

## 🔄 Step 3: Join Alpha Testnet

```bash
aztec-up alpha-testnet
```

---

## 🌐 Step 4: RPC Providers Setup

You will need URLs for:

* **Execution (L1)** – e.g., [Lava](https://gateway.lavanet.xyz/chains)
* **Consensus (Beacon)** – e.g., [Chainstack](https://console.chainstack.com/)


## 🛠️ Setup Guide for Sepolia RPC: [Auto setup RPC and Beacon](./auto_setup_sepolia.md)

> ⚠️ Note: The Aztec client is currently only tested with geth and reth execution clients. Using other clients (e.g., Nethermind or Besu) may result in unexpected behavior or syncing issues.
You may also run Geth + Prysm if preferred.

---

## 🔑 Step 5: Prepare Ethereum Wallet

Use MetaMask or any Ethereum-compatible wallet. Securely store:

* Public address
* Private key (you will paste this into `.env`)

---

## ⛽ Step 6: Get Sepolia ETH (Testnet)

Request funds from:

* [Alchemy Faucet](https://sepoliafaucet.com/)
* [QuickNode](https://faucet.quicknode.com/ethereum/sepolia)
* [Infura](https://www.infura.io/faucet/sepolia)
* [Chainlink Faucet](https://faucets.chain.link/sepolia)

---

## 🌍 Step 7: Get Public IP

```bash
curl ipv4.icanhazip.com
```

---

## 🗃️ Step 8: Create .env file

Example:

```env
ETHEREUM_HOSTS=https://sepolia.rpc.url
L1_CONSENSUS_HOST_URLS=https://beacon.rpc.url
VALIDATOR_PRIVATE_KEY=0xYourPrivateKey
VALIDATOR_ADDRESS=0xYourAddress
P2P_IP=YourServerPublicIP
```

---

## 🐳 Step 9: Docker Compose

```yaml
services:
  aztec-node:
    container_name: aztec-sequencer
    image: aztecprotocol/aztec:0.85.0-alpha-testnet.8
    restart: unless-stopped
    environment:
      ETHEREUM_HOSTS: ${ETHEREUM_HOSTS}
      L1_CONSENSUS_HOST_URLS: ${L1_CONSENSUS_HOST_URLS}
      VALIDATOR_PRIVATE_KEY: ${VALIDATOR_PRIVATE_KEY}
      P2P_IP: ${P2P_IP}
      LOG_LEVEL: debug
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
```

Start:

```bash
docker compose --env-file .env up -d
```

---

## ⏳ Step 10: Wait for Node to Sync

Monitor logs:

```bash
docker logs -f aztec-sequencer
```

---

## 🧾 Step 11: Generate Proof for Role Verification

1. Get block number:

```bash
BLOCK=$(curl -s -X POST -H 'Content-Type: application/json' \
-d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' \
http://localhost:8080 | jq -r ".result.proven.number")
echo $BLOCK
```

2. Get proof:

```bash
curl -s -X POST -H 'Content-Type: application/json' \
-d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[\"$BLOCK\",\"$BLOCK\"],\"id\":67}" \
http://localhost:8080 | jq -r ".result"
```
or one commmand 
```
BLOCK=$(curl -s -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' http://localhost:8080 | jq -r ".result.proven.number") && echo "Block: $BLOCK" && RESULT=$(curl -s -X POST -H 'Content-Type: application/json' -d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[\"$BLOCK\",\"$BLOCK\"],\"id\":67}" http://localhost:8080 | jq -r ".result") && echo "Result:" && echo "$RESULT"
```
3. Go to Discord and run `/operator start`, then enter:

* `address`: your wallet
* `block-number`: from step 1
* `proof`: from step 2

---

## 📝 Step 12: Register Your Validator

```bash
aztec add-l1-validator \
  --l1-rpc-urls RPC_URL \
  --private-key your-private-key \
  --attester your-validator-address \
  --proposer-eoa your-validator-address \
  --staking-asset-handler 0xF739D03e98e23A7B65940848aBA8921fF3bAc4b2 \
  --l1-chain-id 11155111
```

---

## 📊 Step 13: Validator Dashboard

Track your validator status here:
👉 [https://aztecscan.xyz/validators](https://aztecscan.xyz/validators)

---

## 🔒 Step 14: Firewall (Optional)

```bash
ufw allow 22
ufw allow ssh
ufw allow 40400
ufw allow 8080
ufw enable
```

---

## 🩺 Health Check – Verify Full Sync

To check if your node is fully synced with the network, compare its block height with a trusted live RPC endpoint:

```bash
bash <(curl -s https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/sync-check.sh)
```

🎉 **Setup Complete**

Your Aztec Sequencer Node is now live and syncing. You're ready to earn the Apprentice role and contribute to the testnet. Good luck!

---

# 🔧 Aztec Sequencer Upgrade – Docker Guide

To update your Aztec node with the latest `GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS` and restart the container, run the following one-liner command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/cerberus-node/aztec-network/main/governance-update.sh)"
```

> ✅ **Note**: You must run this script from the same directory where `docker-compose.yml` is located.

---

## 🧪 Final Check – Logs

After running the upgrade script, verify that your node starts syncing correctly:

```bash
docker logs -f aztec-sequencer
```

If you want to perform a health check:

```bash
bash <(curl -s https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/sync-check.sh)
```

---

🎉 You’re now upgraded to the latest testnet version and ready to rejoin the Aztec network!

