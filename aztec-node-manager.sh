#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# First run flag
FIRST_RUN="true"

# Configuration
NODE_DIR="$HOME/sepolia-node"
DOCKER_COMPOSE_FILE="$NODE_DIR/docker-compose.yml"
AZTEC_DIR="$HOME/aztec-sequencer"
CONFIG_FILE="$HOME/.node-manager-config"

# Detect OS for sed compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    SED_INPLACE="sed -i.bak"
else
    # Linux and others
    SED_INPLACE="sed -i"
fi

# Function to save configuration
save_config() {
    local key=$1
    local value=$2
    # Create config file if it doesn't exist
    touch "$CONFIG_FILE"
    # Remove existing key if present
    sed -i "/^$key=/d" "$CONFIG_FILE"
    # Add new key-value pair
    echo "$key=$value" >> "$CONFIG_FILE"
}

# Function to load configuration
load_config() {
    local key=$1
    if [ -f "$CONFIG_FILE" ]; then
        grep "^$key=" "$CONFIG_FILE" | tail -n 1 | cut -d'=' -f2-
    fi
}

# Function to display menu
show_menu() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}  ██████╗███████╗██████╗ ███████╗██████╗ ██╗   ██╗███████╗${NC}"
    echo -e "${YELLOW} ██╔════╝██╔════╝██╔══██╗██╔════╝██╔══██╗██║   ██║██╔════╝${NC}"
    echo -e "${YELLOW} ██║     █████╗  ██████╔╝█████╗  ██████╔╝██║   ██║███████╗${NC}"
    echo -e "${YELLOW} ██║     ██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██║   ██║╚════██║${NC}"
    echo -e "${YELLOW} ╚██████╗███████╗██║  ██║███████╗██║  ██║╚██████╔╝███████║${NC}"
    echo -e "${YELLOW}  ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}    🦾 Aztec Sequencer Node Manager v1.1.0     ${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}🤖 Telegram Bot: @cerberus_service_bot${NC}"
    echo -e "${YELLOW}💡 Get RPC endpoints & support via Telegram${NC}"
    echo -e "${BLUE}-------------------------------------------------${NC}"
    echo -e "[1] Setup Geth + Beacon Node"
    echo -e "[2] Setup Aztec Sequencer"
    echo -e "[3] Control Services"
    echo -e "[4] View Logs"
    echo -e "[5] Node Status (Sync & Health)"
    echo -e "[6] Shell Access (Geth/Beacon/Aztec)"
    echo -e "[7] Buy RPC/Beacon Key (From Cerberus Service)"
    echo -e "[8] Upgrade Sequencer Node"
    echo -e "[9] Manage Governance Proposal"
    echo -e "[10] Manage Environment Variables"
    echo -e "[11] Configure Firewall"
    echo -e "[12] Manage Services (Start/Stop/Restart)"
    echo -e "[13] Show Aztec Peer ID (from logs)"
    echo -e "[14] Aztec Auto Restart"
    echo -e "[99] Factory Reset (DANGER)"
    echo -e "[0] Exit"
    echo -e "${BLUE}-------------------------------------------------${NC}"
    echo -e "${GREEN}Powered by CERBERUS NODE - Your Trusted Node Operator${NC}"
    echo -e "${BLUE}=================================================${NC}"
}

# Function to show welcome message
show_welcome() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}  ██████╗███████╗██████╗ ███████╗██████╗ ██╗   ██╗███████╗${NC}"
    echo -e "${YELLOW} ██╔════╝██╔════╝██╔══██╗██╔════╝██╔══██╗██║   ██║██╔════╝${NC}"
    echo -e "${YELLOW} ██║     █████╗  ██████╔╝█████╗  ██████╔╝██║   ██║███████╗${NC}"
    echo -e "${YELLOW} ██║     ██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██║   ██║╚════██║${NC}"
    echo -e "${YELLOW} ╚██████╗███████╗██║  ██║███████╗██║  ██║╚██████╔╝███████║${NC}"
    echo -e "${YELLOW}  ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Welcome to Aztec Sequencer Node Manager!${NC}"
    echo -e "${YELLOW}Your trusted partner in node operation${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}🤖 Telegram Bot: @cerberus_service_bot${NC}"
    echo -e "${YELLOW}💡 Get RPC endpoints & support via Telegram${NC}"
    echo -e "${BLUE}=================================================${NC}"
    sleep 1
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null || ! command -v docker compose &> /dev/null; then
        echo -e "${YELLOW}Docker or Docker Compose not found. Installing Docker...${NC}"
        
        # Remove old Docker packages
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
            sudo apt-get remove -y $pkg || true
        done
        
        # Install Docker
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
        
        echo -e "${GREEN}Docker installed successfully!${NC}"
    else
        echo -e "${GREEN}Docker and Docker Compose are already installed.${NC}"
    fi
}

# Function to check if Docker Compose is installed
check_docker_compose() {
    if ! command -v docker compose &> /dev/null; then
        echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
        exit 1
    fi
}

# Function to setup firewall ports
setup_firewall_ports() {
    local service=$1
    echo -e "${YELLOW}Configuring firewall for $service...${NC}"
    
    # Check if ufw is installed
    if ! command -v ufw &> /dev/null; then
        echo -e "${YELLOW}Installing ufw...${NC}"
        sudo apt-get update
        sudo apt-get install -y ufw
    fi
    
    # Check if ufw is active
    if ! sudo ufw status | grep -q "Status: active"; then
        echo -e "${YELLOW}Enabling ufw...${NC}"
        sudo ufw --force enable
    fi
    
    case $service in
        "aztec")
            echo -e "${YELLOW}Opening ports for Aztec Sequencer...${NC}"
            sudo ufw allow 40400/tcp comment 'Aztec Sequencer TCP' 2>/dev/null || true
            sudo ufw allow 40400/udp comment 'Aztec Sequencer UDP' 2>/dev/null || true
            sudo ufw allow 8080/tcp comment 'Aztec Sequencer API' 2>/dev/null || true
            ;;
        "geth")
            echo -e "${YELLOW}Opening ports for Geth...${NC}"
            sudo ufw allow 30303/tcp comment 'Geth P2P TCP' 2>/dev/null || true
            sudo ufw allow 30303/udp comment 'Geth P2P UDP' 2>/dev/null || true
            sudo ufw allow 8545/tcp comment 'Geth RPC' 2>/dev/null || true
            ;;
        "beacon")
            echo -e "${YELLOW}Opening ports for Beacon...${NC}"
            sudo ufw allow 12000/udp comment 'Beacon P2P UDP' 2>/dev/null || true
            sudo ufw allow 13000/tcp comment 'Beacon P2P TCP' 2>/dev/null || true
            sudo ufw allow 5052/tcp comment 'Beacon API' 2>/dev/null || true
            ;;
    esac
    
    # Always ensure SSH is allowed
    sudo ufw allow ssh comment 'SSH' 2>/dev/null || true
}

# Function to setup Geth + Beacon Node
setup_eth_node() {
    echo -e "${YELLOW}Setting up Geth + Beacon Node...${NC}"
    
    # Create directory if it doesn't exist
    mkdir -p "$NODE_DIR"

    # Configure firewall for Geth and Beacon
    setup_firewall_ports "geth"
    setup_firewall_ports "beacon"
  
    # Download setup script
    curl -sL https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/auto-setup-sepolia.sh -o "$NODE_DIR/auto-setup-sepolia.sh"
    chmod +x "$NODE_DIR/auto-setup-sepolia.sh"
    
    # Run setup script
    echo -e "${YELLOW}Running setup script...${NC}"
    cd "$NODE_DIR" && ./auto-setup-sepolia.sh
    
    # Check if setup was successful
    if [ $? -ne 0 ]; then
        echo -e "${RED}Setup failed! Please check the logs above for errors.${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi

    # Get beacon client for displaying endpoints
    local beacon=""
    if grep -q "prysm:" "$NODE_DIR/docker-compose.yml"; then
        beacon="prysm"
    else
        beacon="lighthouse"
    fi

    # Verify services are running
    echo -e "${YELLOW}Verifying services...${NC}"
    if ! docker ps | grep -q "geth"; then
        echo -e "${RED}Geth is not running!${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    if [ "$beacon" = "prysm" ] && ! docker ps | grep -q "prysm"; then
        echo -e "${RED}Prysm beacon client is not running!${NC}"
        read -p "Press Enter to continue..."
        return 1
    elif [ "$beacon" = "lighthouse" ] && ! docker ps | grep -q "lighthouse"; then
        echo -e "${RED}Lighthouse beacon client is not running!${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi

    PUBLIC_IP=$(curl -s ipv4.icanhazip.com)

    echo -e "${GREEN}Geth + Beacon Node setup completed!${NC}"
    echo -e "${YELLOW}Local RPC:${NC} http://localhost:8545"
    echo -e "${YELLOW}Public RPC:${NC} http://${PUBLIC_IP}:8545"
    if [ "$beacon" = "prysm" ]; then
        echo -e "${YELLOW}Local Beacon:${NC} http://localhost:3500"
        echo -e "${YELLOW}Public Beacon:${NC} http://${PUBLIC_IP}:3500"
    else
        echo -e "${YELLOW}Local Beacon:${NC} http://localhost:5052"
        echo -e "${YELLOW}Public Beacon:${NC} http://${PUBLIC_IP}:5052"
    fi
    
    echo -e "\n${YELLOW}Checking node status...${NC}"
    if curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | grep -q "false"; then
        echo -e "${GREEN}Geth is fully synced!${NC}"
    else
        echo -e "${YELLOW}Geth is still syncing...${NC}"
    fi
    
    if [ "$beacon" = "prysm" ]; then
        if curl -s http://localhost:3500/eth/v1/node/syncing | grep -q "false"; then
            echo -e "${GREEN}Prysm beacon is fully synced!${NC}"
        else
            echo -e "${YELLOW}Prysm beacon is still syncing...${NC}"
        fi
    else
        if curl -s http://localhost:5052/eth/v1/node/syncing | grep -q "false"; then
            echo -e "${GREEN}Lighthouse beacon is fully synced!${NC}"
        else
            echo -e "${YELLOW}Lighthouse beacon is still syncing...${NC}"
        fi
    fi
    
    read -p "Press Enter to continue..."
}

# Function to setup Aztec Sequencer
setup_aztec_sequencer() {
    echo -e "${YELLOW}Setting up Aztec Sequencer...${NC}"
    
    INSTALL_DIR="aztec-sequencer"
    echo "📁 Creating project directory: $INSTALL_DIR"
    cd ~
    mkdir -p $INSTALL_DIR && cd $INSTALL_DIR
    
    # Load saved RPC and Beacon URLs
    local saved_rpc_url=$(load_config "ETH_RPC_URL")
    local saved_beacon_url=$(load_config "ETH_BEACON_URL")
    
    # Prompt for URLs with saved values as defaults
    read -p "🔗 Enter Ethereum RPC URL [$saved_rpc_url]: " ETHEREUM_HOSTS
    ETHEREUM_HOSTS=${ETHEREUM_HOSTS:-$saved_rpc_url}
    
    read -p "🔗 Enter Beacon RPC URL [$saved_beacon_url]: " L1_CONSENSUS_HOST_URLS
    L1_CONSENSUS_HOST_URLS=${L1_CONSENSUS_HOST_URLS:-$saved_beacon_url}
    
    # Save the final values
    save_config "ETH_RPC_URL" "$ETHEREUM_HOSTS"
    save_config "ETH_BEACON_URL" "$L1_CONSENSUS_HOST_URLS"
    
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
    
    # Configure firewall for Aztec Sequencer
    setup_firewall_ports "aztec"
    
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
    
    echo -e "${GREEN}Aztec Sequencer setup completed!${NC}"
    read -p "Press Enter to continue..."
}

# Function to control services
control_services() {
    while true; do
        echo -e "\n${BLUE}Service Control Menu:${NC}"
        echo "1) Start Geth"
        echo "2) Stop Geth"
        echo "3) Start Beacon Node"
        echo "4) Stop Beacon Node"
        echo "5) Start Aztec Sequencer"
        echo "6) Stop Aztec Sequencer"
        echo "0) Back to main menu"
        
        read -p "Enter your choice: " service_choice
        
        case $service_choice in
            1)
                if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                    cd ~ && cd "$NODE_DIR" && docker compose up -d geth
                    echo -e "${GREEN}Geth started!${NC}"
                else
                    echo -e "${RED}ETH Node not set up yet.${NC}"
                fi
                ;;
            2)
                if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                    cd ~ && cd "$NODE_DIR" && docker compose stop geth
                    echo -e "${GREEN}Geth stopped!${NC}"
                fi
                ;;
            3)
                if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                    cd ~ && cd "$NODE_DIR" && docker compose up -d prysm
                    echo -e "${GREEN}Beacon Node started!${NC}"
                else
                    echo -e "${RED}ETH Node not set up yet.${NC}"
                fi
                ;;
            4)
                if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                    cd ~ && cd "$NODE_DIR" && docker compose stop prysm
                    echo -e "${GREEN}Beacon Node stopped!${NC}"
                fi
                ;;
            5)
                if [ -d "$AZTEC_DIR" ]; then
                    cd ~ && cd "$AZTEC_DIR" && docker compose up -d
                    echo -e "${GREEN}Aztec Sequencer started!${NC}"
                else
                    echo -e "${RED}Aztec Sequencer not set up yet.${NC}"
                fi
                ;;
            6)
                if [ -d "$AZTEC_DIR" ]; then
                    cd ~ && cd "$AZTEC_DIR" && docker compose down
                    echo -e "${GREEN}Aztec Sequencer stopped!${NC}"
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid choice!${NC}"
                ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Function to view logs
view_logs() {
    echo -e "${YELLOW}Select service to view logs:${NC}"
    echo "1) Geth"
    echo "2) Beacon Node"
    echo "3) Aztec Sequencer"
    echo "0) Back to main menu"
    
    read -p "Enter your choice: " log_choice
    
    case $log_choice in
        1)
            cd ~ && cd "$NODE_DIR" && docker compose logs -f geth
            ;;
        2)
            cd ~ && cd "$NODE_DIR"
            # Check which beacon client is configured
            if docker compose config | grep -q "prysm:"; then
                echo -e "${BLUE}Viewing Prysm beacon logs...${NC}"
                docker compose logs -f prysm
            elif docker compose config | grep -q "lighthouse:"; then
                echo -e "${BLUE}Viewing Lighthouse beacon logs...${NC}"
                docker compose logs -f lighthouse
            else
                echo -e "${RED}No beacon client found in configuration!${NC}"
            fi
            ;;
        3)
            cd ~ && cd "$AZTEC_DIR" && docker compose logs -f aztec-node
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Function to check node status
check_status() {
    echo -e "${YELLOW}Select service to check:${NC}"
    echo "1) Geth Node"
    echo "2) Beacon Node"
    echo "3) Aztec Node"
    echo "4) All Services"
    read -p "Enter your choice (1-4): " choice

    case $choice in
        1)
            check_geth_status
            ;;
        2)
            check_beacon_status
            ;;
        3)
            check_aztec_status
            ;;
        4)
            check_all_services
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1-4${NC}"
            return
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

check_geth_status() {
    echo -e "\n${BLUE}Geth Status:${NC}"
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        read -p "Enter Geth RPC port (default: 8545): " GETH_PORT
        GETH_PORT=${GETH_PORT:-8545}
        
        RESPONSE=$(curl -s -X POST http://localhost:$GETH_PORT \
            -H 'Content-Type: application/json' \
            -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}')
        
        if [[ "$RESPONSE" == *"false"* ]]; then
            echo -e "${GREEN}✅ Geth node is fully synced!${NC}"
        elif [[ "$RESPONSE" == *"currentBlock"* ]]; then
            CURRENT=$(echo "$RESPONSE" | jq -r '.result.currentBlock')
            HIGHEST=$(echo "$RESPONSE" | jq -r '.result.highestBlock')
            echo -e "${YELLOW}⏳ Geth node is syncing... ($CURRENT / $HIGHEST)${NC}"
        else
            echo -e "${RED}❌ Unable to determine Geth sync status${NC}"
        fi
    else
        echo -e "${RED}ETH Node not set up yet.${NC}"
    fi
}

check_beacon_status() {
    echo -e "\n${BLUE}Beacon Node Status:${NC}"
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        read -p "Enter Beacon API port (default: 5052): " BEACON_PORT
        BEACON_PORT=${BEACON_PORT:-5052}
        
        # Check syncing status
        SYNC_RESPONSE=$(curl -s http://localhost:$BEACON_PORT/eth/v1/node/syncing)
        if [[ "$SYNC_RESPONSE" == *"false"* ]]; then
            echo -e "${GREEN}✅ Beacon node is fully synced!${NC}"
        elif [[ "$SYNC_RESPONSE" == *"true"* ]]; then
            echo -e "${YELLOW}⏳ Beacon node is still syncing${NC}"
        else
            echo -e "${RED}❌ Unable to determine Beacon sync status${NC}"
        fi
    else
        echo -e "${RED}ETH Node not set up yet.${NC}"
    fi
}

# Function to get latest proven block from AztecScan API
get_latest_proven_block() {
    local API_KEY="temporary-api-key"
    local API_URL="https://api.testnet.aztecscan.xyz/v1/$API_KEY/l2/ui/blocks-for-table"
    local BATCH_SIZE=20
    local FOUND=0

    # Get latest block height
    local LATEST_BLOCK=$(curl -s "$API_URL?from=0&to=0" | jq -r '.[0].height')
    
    if [ -z "$LATEST_BLOCK" ] || [ "$LATEST_BLOCK" == "null" ]; then
        echo "N/A"
        return
    fi

    local CURRENT_HEIGHT=$LATEST_BLOCK

    # Search backwards for blockStatus = 4
    while [ $FOUND -eq 0 ]; do
        local FROM_HEIGHT=$((CURRENT_HEIGHT - BATCH_SIZE + 1))
        if [ $FROM_HEIGHT -lt 0 ]; then
            FROM_HEIGHT=0
        fi

        local RESPONSE=$(curl -s "$API_URL?from=$FROM_HEIGHT&to=$CURRENT_HEIGHT")
        local MATCH=$(echo "$RESPONSE" | jq -r '.[] | select(.blockStatus == 4) | .height' | sort -nr | head -n1)

        if [ -n "$MATCH" ] && [ "$MATCH" != "null" ]; then
            echo "$MATCH"
            return
        else
            CURRENT_HEIGHT=$((FROM_HEIGHT - 1))
            if [ $CURRENT_HEIGHT -lt 0 ]; then
                echo "N/A"
                return
            fi
        fi
    done
}

check_aztec_status() {
    echo -e "\n${BLUE}Aztec Sequencer Sync Status:${NC}"
    read -p "Enter Aztec RPC port (default: 8080): " LOCAL_AZTEC_PORT
    LOCAL_AZTEC_PORT=${LOCAL_AZTEC_PORT:-8080}
    LOCAL_AZTEC_RPC="http://localhost:$LOCAL_AZTEC_PORT"
    REMOTE_AZTEC_RPC="https://aztec-rpc.cerberusnode.com"

    # Check if local Aztec node is running
    if lsof -i :$LOCAL_AZTEC_PORT >/dev/null 2>&1; then
        LOCAL_RESPONSE=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
            -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$LOCAL_AZTEC_RPC")
        if [ -z "$LOCAL_RESPONSE" ] || [[ "$LOCAL_RESPONSE" == *"error"* ]]; then
            echo -e "${RED}❌ Local Aztec node not responding or returned an error${NC}"
            LOCAL_BLOCK="N/A"
        else
            LOCAL_BLOCK=$(echo "$LOCAL_RESPONSE" | jq -r ".result.proven.number")
        fi
    else
        echo -e "${RED}❌ No Aztec node detected on port $LOCAL_AZTEC_PORT${NC}"
        LOCAL_BLOCK="N/A"
    fi

    # Try RPC first, then fallback to API
    REMOTE_RESPONSE=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$REMOTE_AZTEC_RPC")
    
    if [ -z "$REMOTE_RESPONSE" ] || [[ "$REMOTE_RESPONSE" == *"error"* ]]; then
        echo -e "${YELLOW}⚠️ Remote RPC failed, trying AztecScan API fallback...${NC}"
        REMOTE_BLOCK=$(get_latest_proven_block)
        if [ "$REMOTE_BLOCK" != "N/A" ]; then
            echo -e "${GREEN}✅ Got block from AztecScan API: $REMOTE_BLOCK${NC}"
        else
            echo -e "${RED}❌ Both RPC and API fallback failed${NC}"
        fi
    else
        REMOTE_BLOCK=$(echo "$REMOTE_RESPONSE" | jq -r ".result.proven.number")
    fi

    if [[ "$LOCAL_BLOCK" == "N/A" ]] || [[ "$REMOTE_BLOCK" == "N/A" ]]; then
        echo -e "${RED}❌ Cannot determine Aztec sync status due to an error${NC}"
    elif [ "$LOCAL_BLOCK" = "$REMOTE_BLOCK" ]; then
        echo -e "${GREEN}✅ Aztec node is fully synced! (Block: $LOCAL_BLOCK)${NC}"
    else
        echo -e "${YELLOW}⏳ Aztec node is still syncing... ($LOCAL_BLOCK / $REMOTE_BLOCK)${NC}"
    fi
}

check_all_services() {
    check_geth_status
    check_beacon_status
    check_aztec_status
}

# Function to access shell
shell_access() {
    echo -e "${YELLOW}Select service to access:${NC}"
    echo "1) Geth"
    echo "2) Beacon Node"
    echo "3) Aztec Sequencer"
    echo "0) Back to main menu"
    
    read -p "Enter your choice: " shell_choice
    
    case $shell_choice in
        1)
            cd ~ && cd "$NODE_DIR" && docker compose exec geth sh
            ;;
        2)
            cd ~ && cd "$NODE_DIR" && docker compose exec prysm sh
            ;;
        3)
            if [ -d "$AZTEC_DIR" ]; then
                echo -e "${YELLOW}Accessing Aztec Sequencer container shell...${NC}"
                cd ~ && cd "$AZTEC_DIR" && docker compose exec aztec-node sh
            else
                echo -e "${RED}Aztec Sequencer not set up yet.${NC}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            ;;
    esac
}

# Function to buy RPC/Beacon key
buy_key() {
    while true; do
        clear
        echo -e "${BLUE}=================================================${NC}"
        echo -e "${YELLOW}🤖 Cerberus Service - ETH Sepolia Node Service${NC}"
        echo -e "${BLUE}=================================================${NC}"
        
        echo -e "\n${GREEN}Services Available:${NC}"
        echo -e "• ${YELLOW}Full Package${NC} - RPC + Beacon (Best value)"
        
        echo -e "\n${BLUE}Features:${NC}"
        echo -e "✅ Good support"
        echo -e "✅ High availability"
        echo -e "✅ Low latency"
        echo -e "✅ Cost-effective"
        echo -e "✅ Unlimited requests"
        
        echo -e "\n${YELLOW}Pricing Plans (USDT/USDC):${NC}"
        echo -e "1) ${GREEN}1 Month${NC}  - ${YELLOW}10 USD${NC}"
        echo -e "2) ${GREEN}3 Months${NC} - ${YELLOW}30 USD${NC}"
        echo -e "3) ${GREEN}6 Months${NC} - ${YELLOW}50 USD${NC}"
        echo -e "4) ${GREEN}12 Months${NC} - ${YELLOW}90 USD${NC}"
        
        echo -e "\n${YELLOW}Purchase Options:${NC}"
        echo -e "1) Buy via Telegram Bot"
        echo -e "2) Buy Directly (Coming Soon)"
        echo -e "3) View Service Status"
        echo -e "0) Back to main menu"
        
        read -p "Enter your choice: " purchase_choice
        
        case $purchase_choice in
            1)
                echo -e "\n${YELLOW}Get Started:${NC}"
                echo -e "👉 Visit: ${YELLOW}@cerberus_service_bot${NC}"
                echo -e "📧 Support: ${YELLOW}@cerberus_support${NC}"
                echo -e "\n${BLUE}Select your preferred duration in the bot:${NC}"
                echo -e "• 1 Month  - 10 USD"
                echo -e "• 3 Months - 30 USD"
                echo -e "• 6 Months - 50 USD"
                echo -e "• 12 Months - 90 USD"
                read -p "Press Enter to continue..."
                ;;
            2)
                echo -e "\n${YELLOW}Direct Purchase (Coming Soon)${NC}"
                echo -e "${BLUE}Payment Method:${NC}"
                echo -e "• Crypto (USDT, USDC)"
                echo -e "\n${BLUE}Pricing:${NC}"
                echo -e "• 1 Month  - 10 USD"
                echo -e "• 3 Months - 30 USD"
                echo -e "• 6 Months - 50 USD"
                echo -e "• 12 Months - 90 USD"
                echo -e "\n${BLUE}This feature will be available soon!${NC}"
                read -p "Press Enter to continue..."
                ;;
            3)
                echo -e "\n${BLUE}Checking Cerberus Service Status...${NC}"
                if curl -s https://service.cerberusnode.com/health | grep -q "healthy"; then
                    echo -e "${GREEN}✅ Cerberus Service is online${NC}"
                else
                    echo -e "${RED}❌ Cerberus Service is offline${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid choice!${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Function to factory reset
factory_reset() {
    echo -e "${RED}WARNING: This will delete all node data and configurations!${NC}"
    read -p "Are you sure you want to proceed? (y/N): " confirm
    
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        echo -e "${YELLOW}Performing factory reset...${NC}"
        
        # Stop services
        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
            cd ~ && cd "$NODE_DIR" && docker compose down
        fi
        
        # Remove directories
        rm -rf "$NODE_DIR"
        rm -rf "$AZTEC_DIR"
        
        echo -e "${GREEN}Factory reset completed!${NC}"
    else
        echo -e "${YELLOW}Factory reset cancelled.${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to upgrade sequencer node
upgrade_sequencer() {
    echo -e "${YELLOW}Upgrading Aztec Sequencer Node...${NC}"
    
    if [ ! -d "$AZTEC_DIR" ]; then
        echo -e "${RED}Aztec Sequencer not set up yet. Please run option 2 first.${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    # Ask about data cleanup
    echo -e "\n${YELLOW}Data Management Options:${NC}"
    echo "1) Keep existing data (Recommended for minor updates)"
    echo "2) Clear all data (Recommended for major version changes)"
    echo "0) Cancel upgrade"
    
    read -p "Select data management option: " data_choice
    
    case $data_choice in
        1)
            echo -e "${GREEN}Keeping existing data...${NC}"
            ;;
        2)
            echo -e "${RED}WARNING: This will delete all Aztec node data!${NC}"
            read -p "Are you sure you want to proceed? (y/N): " confirm
            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Upgrade cancelled.${NC}"
                return
            fi
            echo -e "${YELLOW}Clearing Aztec node data...${NC}"
            cd ~ && cd "$AZTEC_DIR" && docker compose down
            cd ~ && cd "$AZTEC_DIR" && rm -rf data/*
            echo -e "${GREEN}Data cleared successfully.${NC}"
            ;;
        0)
            echo -e "${YELLOW}Upgrade cancelled.${NC}"
            return
            ;;
        *)
            echo -e "${RED}Invalid choice. Upgrade cancelled.${NC}"
            return
            ;;
    esac
    
    # Paginated tag selection
    TAGS_URL="https://registry.hub.docker.com/v2/repositories/aztecprotocol/aztec/tags?page_size=20"
    while true; do
        RESPONSE=$(curl -s "$TAGS_URL")
        TAGS=$(echo "$RESPONSE" | jq -r '.results[].name')
        NEXT_URL=$(echo "$RESPONSE" | jq -r '.next')
        TAG_ARRAY=()
        i=1
        echo -e "${BLUE}Available tags:${NC}"
        for tag in $TAGS; do
            echo "  [$i] $tag"
            TAG_ARRAY+=("$tag")
            i=$((i+1))
        done
        echo "  [0] Enter tag manually"
        if [ "$NEXT_URL" != "null" ]; then
            echo "  [N] Next page"
        fi
        read -p "Select a tag by number, 0 to enter manually, or N for next page: " tag_choice
        if [[ "$tag_choice" =~ ^[0-9]+$ ]] && [ "$tag_choice" -ge 1 ] && [ "$tag_choice" -le ${#TAG_ARRAY[@]} ]; then
            SELECTED_TAG="${TAG_ARRAY[$((tag_choice-1))]}"
            break
        elif [ "$tag_choice" = "0" ]; then
            read -p "Enter the tag you want to use (e.g. 0.87.2): " SELECTED_TAG
            break
        elif [[ "$tag_choice" =~ ^[Nn]$ ]] && [ "$NEXT_URL" != "null" ]; then
            TAGS_URL="$NEXT_URL"
            continue
        else
            echo -e "${RED}Invalid choice. Please try again.${NC}"
        fi
    done
    echo -e "${YELLOW}Selected tag: $SELECTED_TAG${NC}"

    # Stop the sequencer if running
    echo -e "${YELLOW}Stopping Aztec Sequencer service...${NC}"
    cd ~ && cd "$AZTEC_DIR" && docker compose down || true

    # Update docker-compose.yml with the selected tag
    if grep -q '^\s*image: aztecprotocol/aztec:' docker-compose.yml; then
        sed -i "s|^\s*image: aztecprotocol/aztec:.*$|    image: aztecprotocol/aztec:$SELECTED_TAG|" docker-compose.yml
    else
        echo -e "${RED}Could not find image line in docker-compose.yml. Please update manually.${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    # Pull latest Docker image
    echo -e "${YELLOW}Pulling Aztec Docker image with tag $SELECTED_TAG...${NC}"
    docker compose pull
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to pull the Docker image.${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    # Restart the sequencer
    echo -e "${YELLOW}Restarting Aztec Sequencer with the selected image...${NC}"
    docker compose --env-file .env up -d
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Sequencer upgrade completed successfully!${NC}"
    else
        echo -e "${RED}Sequencer failed to start after upgrade. Please check logs.${NC}"
    fi
    read -p "Press Enter to continue..."
}

# Function to verify governance settings
verify_governance_settings() {
    echo -e "${YELLOW}Verifying governance settings...${NC}"

    # 1. Check .env file
    echo -e "\n${BLUE}1. Checking .env file:${NC}"
    if grep -q "^GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS=" "$ENV_FILE"; then
        local env_addr
        env_addr=$(grep "^GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS=" "$ENV_FILE" | cut -d'=' -f2)
        echo -e "${GREEN}✅ Found in .env: $env_addr${NC}"
    else
        echo -e "${RED}❌ No governance address found in .env${NC}"
    fi

    # 2. Check docker-compose.yml
    echo -e "\n${BLUE}2. Checking docker-compose.yml:${NC}"
    if grep -q "GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:" "$DOCKER_COMPOSE_FILE"; then
        echo -e "${GREEN}✅ Governance variable found in docker-compose.yml${NC}"
        grep -A 1 -B 1 "GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:" "$DOCKER_COMPOSE_FILE"
    else
        echo -e "${RED}❌ No governance variable found in docker-compose.yml${NC}"
    fi

    # 3. Check container logs
    echo -e "\n${BLUE}3. Checking container logs:${NC}"
    if ! docker ps | grep -q "aztec-sequencer"; then
        echo -e "${RED}❌ Container 'aztec-sequencer' is not running${NC}"
        echo -e "${YELLOW}⏳ Starting container...${NC}"
        cd "$AZTEC_DIR" && docker compose up -d
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to start container${NC}"
            return 1
        fi
        sleep 5
    fi

    echo -e "${YELLOW}🔍 Checking governance proposer logs...${NC}"
    local logs
    logs=$(docker logs aztec-sequencer 2>&1)

    echo -e "${BLUE}Debug: First few lines of logs:${NC}"
    echo "$logs" | head -n 3

    echo -e "${BLUE}Searching for governance in logs...${NC}"
    echo "$logs" | grep -i "governanceProposerPayload" || echo -e "${YELLOW}⚠️ No governance logs found${NC}"

    # 4. Summary
    echo -e "\n${BLUE}Summary:${NC}"
    if grep -q "^GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS=" "$ENV_FILE" && \
       grep -q "GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:" "$DOCKER_COMPOSE_FILE" && \
       docker ps | grep -q "aztec-sequencer" && \
       docker exec aztec-sequencer env | grep -q "GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS"; then
        echo -e "${GREEN}✅ Governance settings appear to be correctly configured${NC}"
    else
        echo -e "${YELLOW}⚠️ Some issues found with governance configuration${NC}"
        echo -e "${YELLOW}Please check the details above and fix any issues${NC}"
    fi
}


# Function to handle governance variable in .env
update_env_governance() {
    local action="$1"   # "add" hoặc "remove"
    local value="$2"    # Ethereum address (chỉ dùng khi add)

    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${RED}.env file not found: $ENV_FILE${NC}"
        return 1
    fi

    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${RED}docker-compose.yml not found: $DOCKER_COMPOSE_FILE${NC}"
        return 1
    fi

    echo -e "${YELLOW}Debug: Current docker-compose.yml content:${NC}"
    cat "$DOCKER_COMPOSE_FILE"

    # Xoá mọi dòng GOV trùng lặp
    $SED_INPLACE '/^GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS[[:space:]]*=/d' "$ENV_FILE"

    if [ "$action" = "add" ]; then
        if [[ ! $value =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            echo -e "${RED}❌ Invalid Ethereum address format: $value${NC}"
            return 1
        fi
        echo "GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS=$value" >> "$ENV_FILE"
        echo -e "${GREEN}✅ Added to .env: $value${NC}"

        # Check if already exists in docker-compose.yml
        if grep -q "GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:" "$DOCKER_COMPOSE_FILE"; then
            echo -e "${YELLOW}Debug: Updating existing GOV var in docker-compose.yml${NC}"
            # Use awk to replace the line
            local temp_file=$(mktemp)
            awk '/GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:/ { print "      GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS: ${GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS}"; next } { print }' "$DOCKER_COMPOSE_FILE" > "$temp_file"
            mv "$temp_file" "$DOCKER_COMPOSE_FILE"
        else
            echo -e "${YELLOW}Debug: Adding new GOV var after VALIDATOR_PRIVATE_KEY${NC}"
            # Use awk to add new line after VALIDATOR_PRIVATE_KEY
            local temp_file=$(mktemp)
            awk '/VALIDATOR_PRIVATE_KEY/ { print; print "      GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS: ${GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS}"; next } { print }' "$DOCKER_COMPOSE_FILE" > "$temp_file"
            mv "$temp_file" "$DOCKER_COMPOSE_FILE"
        fi

        # Verify the change
        if grep -q "GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:" "$DOCKER_COMPOSE_FILE"; then
            echo -e "${GREEN}✅ Verified: GOV var added to docker-compose.yml${NC}"
        else
            echo -e "${RED}❌ Error: Failed to add GOV var to docker-compose.yml${NC}"
            return 1
        fi

    elif [ "$action" = "remove" ]; then
        echo -e "${YELLOW}⚠️ Removed GOV var from .env${NC}"

        # Remove from docker-compose.yml using awk
        local temp_file=$(mktemp)
        awk '!/GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:/' "$DOCKER_COMPOSE_FILE" > "$temp_file"
        mv "$temp_file" "$DOCKER_COMPOSE_FILE"
        echo -e "${YELLOW}⚠️ Removed GOV var from docker-compose.yml${NC}"
    else
        echo -e "${RED}❌ Invalid action. Use 'add' or 'remove'${NC}"
        return 1
    fi
}

# Function to manage governance proposal
manage_governance_proposal() {
    echo -e "${YELLOW}Managing Governance Proposal...${NC}"
    
    if [ ! -d "$AZTEC_DIR" ]; then
        echo -e "${RED}Aztec Sequencer not set up yet. Please run option 2 first.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    ENV_FILE="$AZTEC_DIR/.env"
    DOCKER_COMPOSE_FILE="$AZTEC_DIR/docker-compose.yml"
    
    while true; do
        echo -e "\n${BLUE}Governance Proposal Menu:${NC}"
        echo "1) Add/Edit Proposal Address"
        echo "2) Remove Proposal Address"
        echo "3) Verify Governance Settings"
        echo "0) Back to main menu"
        
        read -p "Enter your choice: " proposal_choice
        
        case $proposal_choice in
            1)
                read -p "Enter governance proposal address (0x...): " proposal_addr
                if [[ $proposal_addr =~ ^0x[a-fA-F0-9]{40}$ ]]; then
                    # Update .env file - only handle governance variable
                    update_env_governance "add" "$proposal_addr"
                    echo -e "${GREEN}Governance proposal address updated in .env!${NC}"
                    
                    # Update docker-compose.yml
                    if grep -q "GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:" "$DOCKER_COMPOSE_FILE"; then
                        # Update existing environment variable using awk
                        local temp_file=$(mktemp)
                        awk '/GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:/ { print "      GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS: ${GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS}"; next } { print }' "$DOCKER_COMPOSE_FILE" > "$temp_file"
                        mv "$temp_file" "$DOCKER_COMPOSE_FILE"
                    else
                        # Add new environment variable using awk
                        local temp_file=$(mktemp)
                        awk '/^    environment:/ { print; print "      GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS: ${GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS}"; next } { print }' "$DOCKER_COMPOSE_FILE" > "$temp_file"
                        mv "$temp_file" "$DOCKER_COMPOSE_FILE"
                    fi
                    echo -e "${GREEN}Governance proposal address updated in docker-compose.yml!${NC}"
                    
                    # Restart the node
                    echo -e "${YELLOW}Restarting Aztec Sequencer...${NC}"
                    cd "$AZTEC_DIR" && docker compose down && docker compose up -d
                    
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}Node restarted successfully with new governance settings!${NC}"
                    else
                        echo -e "${RED}Failed to restart node. Please check logs.${NC}"
                    fi
                else
                    echo -e "${RED}Invalid Ethereum address format!${NC}"
                fi
                ;;
            2)
                if grep -q "^GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS=" "$ENV_FILE"; then
                    # Remove only governance variable from .env
                    update_env_governance "remove"
                    echo -e "${GREEN}Governance proposal address removed from .env!${NC}"
                    
                    # Remove from docker-compose.yml using awk
                    local temp_file=$(mktemp)
                    awk '!/GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS:/' "$DOCKER_COMPOSE_FILE" > "$temp_file"
                    mv "$temp_file" "$DOCKER_COMPOSE_FILE"
                    echo -e "${GREEN}Governance proposal address removed from docker-compose.yml!${NC}"
                    
                    # Restart the node
                    echo -e "${YELLOW}Restarting Aztec Sequencer...${NC}"
                    cd "$AZTEC_DIR" && docker compose down && docker compose up -d
                    
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}Node restarted successfully!${NC}"
                    else
                        echo -e "${RED}Failed to restart node. Please check logs.${NC}"
                    fi
                else
                    echo -e "${YELLOW}No governance proposal address found in .env${NC}"
                fi
                ;;
            3)
                verify_governance_settings
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid choice!${NC}"
                ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Function to manage environment variables
manage_env() {
    echo -e "${YELLOW}Managing Sequencer Environment Variables...${NC}"
    
    if [ ! -d "$AZTEC_DIR" ]; then
        echo -e "${RED}Aztec Sequencer not set up yet. Please run option 2 first.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    ENV_FILE="$AZTEC_DIR/.env"
    
    # Create .env if it doesn't exist
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}Creating new .env file...${NC}"
        touch "$ENV_FILE"
    fi
    
    while true; do
        echo -e "\n${BLUE}Environment Variables Menu:${NC}"
        echo "1) View current .env"
        echo "2) Edit .env manually"
        echo "3) Add/Update variable"
        echo "4) Remove variable"
        echo "5) Create from template"
        echo "0) Back to main menu"
        
        read -p "Enter your choice: " env_choice
        
        case $env_choice in
            1)
                echo -e "\n${BLUE}Current .env contents:${NC}"
                if [ -s "$ENV_FILE" ]; then
                    cat "$ENV_FILE" | grep -v '^#' | grep -v '^$'
                else
                    echo -e "${YELLOW}.env file is empty${NC}"
                fi
                ;;
            2)
                if command -v nano &> /dev/null; then
                    nano "$ENV_FILE"
                elif command -v vim &> /dev/null; then
                    vim "$ENV_FILE"
                else
                    echo -e "${RED}No text editor found. Please install nano or vim.${NC}"
                fi
                ;;
            3)
                read -p "Enter variable name: " var_name
                read -p "Enter variable value: " var_value
                
                # Remove existing variable if it exists
                sed -i "/^$var_name=/d" "$ENV_FILE"
                
                # Add new variable
                echo "$var_name=$var_value" >> "$ENV_FILE"
                echo -e "${GREEN}Variable updated successfully!${NC}"
                ;;
            4)
                read -p "Enter variable name to remove: " var_name
                sed -i "/^$var_name=/d" "$ENV_FILE"
                echo -e "${GREEN}Variable removed successfully!${NC}"
                ;;
            5)
                echo -e "${YELLOW}Creating .env from template...${NC}"
                # Create new .env with template
                cat > "$ENV_FILE" << EOF
# Aztec Sequencer Environment Variables
# Generated on $(date)

# Required Environment Variables
ETHEREUM_HOSTS=http://localhost:8545
L1_CONSENSUS_HOST_URLS=http://localhost:5052
VALIDATOR_PRIVATE_KEYS=your_private_key_here
VALIDATOR_ADDRESS=your_validator_address_here
P2P_IP=your_public_ip

# Optional Configuration
LOG_LEVEL=debug
SEQ_PUBLISHER_PRIVATE_KEY=your_seq_publisher_private_key_here
EOF
                echo -e "${GREEN}Template .env created!${NC}"
                echo -e "${YELLOW}Please review and modify the template as needed.${NC}"
                ;;
            0)
                # Clean up any backup files
                cleanup_backup_files
                return
                ;;
            *)
                echo -e "${RED}Invalid choice!${NC}"
                ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Function to clean up backup files
cleanup_backup_files() {
    find "$AZTEC_DIR" -name "*.bak" -type f -delete
}

# Function to configure firewall (now uses the helper function)
configure_firewall() {
    echo -e "${YELLOW}Configuring Firewall...${NC}"
    
    # Configure all services
    setup_firewall_ports "aztec"
    setup_firewall_ports "geth"
    setup_firewall_ports "beacon"
    
    # Show status
    echo -e "\n${GREEN}Firewall Status:${NC}"
    sudo ufw status numbered
    
    echo -e "\n${GREEN}Firewall configuration completed!${NC}"
    echo -e "${YELLOW}Note: Make sure to keep your SSH port secure${NC}"
    read -p "Press Enter to continue..."
}

# Function to manage services
manage_services() {
    while true; do
        echo -e "\n${BLUE}Service Management Menu:${NC}"
        echo "1) Manage Geth"
        echo "2) Manage Beacon Node"
        echo "3) Manage Aztec Sequencer"
        echo "4) Manage All Services"
        echo "0) Back to main menu"
        
        read -p "Enter your choice: " service_choice
        
        case $service_choice in
            1)
                echo -e "\n${BLUE}Geth Service Management:${NC}"
                echo "1) Start Geth"
                echo "2) Stop Geth"
                echo "3) Restart Geth"
                echo "0) Back"
                
                read -p "Enter your choice: " geth_choice
                
                case $geth_choice in
                    1)
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            cd ~ && cd "$NODE_DIR" && docker compose up -d geth
                            echo -e "${GREEN}Geth started!${NC}"
                        else
                            echo -e "${RED}ETH Node not set up yet.${NC}"
                        fi
                        ;;
                    2)
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            cd ~ && cd "$NODE_DIR" && docker compose stop geth
                            echo -e "${GREEN}Geth stopped!${NC}"
                        fi
                        ;;
                    3)
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            cd ~ && cd "$NODE_DIR" && docker compose restart geth
                            echo -e "${GREEN}Geth restarted!${NC}"
                        fi
                        ;;
                    0)
                        continue
                        ;;
                    *)
                        echo -e "${RED}Invalid choice!${NC}"
                        ;;
                esac
                ;;
            2)
                echo -e "\n${BLUE}Beacon Node Service Management:${NC}"
                echo "1) Start Beacon Node"
                echo "2) Stop Beacon Node"
                echo "3) Restart Beacon Node"
                echo "0) Back"
                
                read -p "Enter your choice: " beacon_choice
                
                case $beacon_choice in
                    1)
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            cd ~ && cd "$NODE_DIR" && docker compose up -d prysm
                            echo -e "${GREEN}Beacon Node started!${NC}"
                        else
                            echo -e "${RED}ETH Node not set up yet.${NC}"
                        fi
                        ;;
                    2)
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            cd ~ && cd "$NODE_DIR" && docker compose stop prysm
                            echo -e "${GREEN}Beacon Node stopped!${NC}"
                        fi
                        ;;
                    3)
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            cd ~ && cd "$NODE_DIR" && docker compose restart prysm
                            echo -e "${GREEN}Beacon Node restarted!${NC}"
                        fi
                        ;;
                    0)
                        continue
                        ;;
                    *)
                        echo -e "${RED}Invalid choice!${NC}"
                        ;;
                esac
                ;;
            3)
                echo -e "\n${BLUE}Aztec Sequencer Service Management:${NC}"
                echo "1) Start Aztec Sequencer"
                echo "2) Stop Aztec Sequencer"
                echo "3) Restart Aztec Sequencer"
                echo "0) Back"
                
                read -p "Enter your choice: " aztec_choice
                
                case $aztec_choice in
                    1)
                        if [ -d "$AZTEC_DIR" ]; then
                            cd ~ && cd "$AZTEC_DIR" && docker compose up -d
                            echo -e "${GREEN}Aztec Sequencer started!${NC}"
                        else
                            echo -e "${RED}Aztec Sequencer not set up yet.${NC}"
                        fi
                        ;;
                    2)
                        if [ -d "$AZTEC_DIR" ]; then
                            cd ~ && cd "$AZTEC_DIR" && docker compose down
                            echo -e "${GREEN}Aztec Sequencer stopped!${NC}"
                        fi
                        ;;
                    3)
                        if [ -d "$AZTEC_DIR" ]; then
                            cd ~ && cd "$AZTEC_DIR" && docker compose down && docker compose up -d
                            echo -e "${GREEN}Aztec Sequencer restarted!${NC}"
                        fi
                        ;;
                    0)
                        continue
                        ;;
                    *)
                        echo -e "${RED}Invalid choice!${NC}"
                        ;;
                esac
                ;;
            4)
                echo -e "\n${BLUE}Manage All Services:${NC}"
                echo "1) Start All Services"
                echo "2) Stop All Services"
                echo "3) Restart All Services"
                echo "0) Back"
                
                read -p "Enter your choice: " all_choice
                
                case $all_choice in
                    1)
                        # Start Geth and Beacon
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            cd ~ && cd "$NODE_DIR" && docker compose up -d
                            echo -e "${GREEN}Geth and Beacon Node started!${NC}"
                        fi
                        # Start Aztec
                        if [ -d "$AZTEC_DIR" ]; then
                            cd ~ && cd "$AZTEC_DIR" && docker compose up -d
                            echo -e "${GREEN}Aztec Sequencer started!${NC}"
                        fi
                        ;;
                    2)
                        # Stop Aztec first
                        if [ -d "$AZTEC_DIR" ]; then
                            cd ~ && cd "$AZTEC_DIR" && docker compose down
                            echo -e "${GREEN}Aztec Sequencer stopped!${NC}"
                        fi
                        # Stop Geth and Beacon
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            cd ~ && cd "$NODE_DIR" && docker compose down
                            echo -e "${GREEN}Geth and Beacon Node stopped!${NC}"
                        fi
                        ;;
                    3)
                        # Restart Aztec
                        if [ -d "$AZTEC_DIR" ]; then
                            cd ~ && cd "$AZTEC_DIR" && docker compose down && docker compose up -d
                            echo -e "${GREEN}Aztec Sequencer restarted!${NC}"
                        fi
                        # Restart Geth and Beacon
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            cd ~ && cd "$NODE_DIR" && docker compose down && docker compose up -d
                            echo -e "${GREEN}Geth and Beacon Node restarted!${NC}"
                        fi
                        ;;
                    0)
                        continue
                        ;;
                    *)
                        echo -e "${RED}Invalid choice!${NC}"
                        ;;
                esac
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid choice!${NC}"
                ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Function to show Aztec Sequencer peer ID
export_peer_id() {
    if [ -d "$AZTEC_DIR" ]; then
        # Check if Aztec node is running
        if docker ps | grep -q "aztec-sequencer"; then
            # Try multiple patterns to find peer ID
            echo -e "${YELLOW}Searching for peer ID in logs...${NC}"
            
            # Pattern 1: JSON format with "peerId"
            PEER_ID=$(docker logs aztec-sequencer 2>&1 | grep -i "peerId" | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4 | head -n 1)
        
            
            # Pattern 4: Plain text format with "peerId:"
            if [ -z "$PEER_ID" ]; then
                PEER_ID=$(docker logs aztec-sequencer 2>&1 | grep -i "peerId:" | grep -oP '(?<=peerId: )[^ ]*' | head -n 1)
            fi
            
            if [ ! -z "$PEER_ID" ]; then
                echo -e "${GREEN}✅ Peer ID found:${NC}"
                echo "$PEER_ID"
                
                # Save to clipboard if possible
                if command -v pbcopy &> /dev/null; then
                    echo "$PEER_ID" | pbcopy
                    echo -e "${GREEN}📋 Peer ID copied to clipboard${NC}"
                elif command -v xclip &> /dev/null; then
                    echo "$PEER_ID" | xclip -selection clipboard
                    echo -e "${GREEN}📋 Peer ID copied to clipboard${NC}"
                fi
                echo -e "${GREEN} Verify the peer ID on https://aztec.nethermind.io ${NC}"
                # Save to file
                echo "$PEER_ID" > "$AZTEC_DIR/peer_id.txt"
                echo -e "${GREEN}💾 Peer ID saved to $AZTEC_DIR/peer_id.txt${NC}"
            else
                echo -e "${RED}❌ Failed to find peer ID in logs.${NC}"
                echo -e "${YELLOW}Possible reasons:${NC}"
                echo "1. Node is still starting up"
                echo "2. Node logs have been rotated"
                echo "3. Different log format"
                echo -e "\n${YELLOW}Suggestions:${NC}"
                echo "1. Wait a few minutes and try again"
                echo "2. Restart the node to see startup logs"
                echo "3. Check logs manually: docker logs aztec-sequencer"
            fi
        else
            echo -e "${RED}❌ Aztec Sequencer node is not running.${NC}"
            echo -e "${YELLOW}Please start the node first:${NC}"
            echo "1. Go to main menu"
            echo "2. Select option 12 (Manage Services)"
            echo "3. Choose option 3 (Manage Aztec Sequencer)"
            echo "4. Select option 1 (Start Aztec Sequencer)"
        fi
    else
        echo -e "${RED}❌ Aztec Sequencer not set up yet.${NC}"
        echo -e "${YELLOW}Please set up the sequencer first:${NC}"
        echo "1. Go to main menu"
        echo "2. Select option 2 (Setup Aztec Sequencer)"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to monitor Aztec node health and auto-restart if needed
monitor_aztec_health() {
    local interval=60 # seconds
    local max_fail=3
    local fail_count=0
    local aztec_dir="$AZTEC_DIR"
    local log_file="$aztec_dir/health_monitor.log"
    echo -e "${YELLOW}Starting Aztec node health monitor (interval: ${interval}s, max fail: $max_fail)...${NC}"
    echo "[INFO] Health monitor started at $(date)" >> "$log_file"
    while true; do
        # Check if container exists and is running
        if ! docker ps | grep -q "aztec-sequencer"; then
            fail_count=$((fail_count+1))
            echo -e "${RED}Aztec node container not running ($fail_count/$max_fail) at $(date)${NC}"
            echo "[WARN] Container not running at $(date) ($fail_count/$max_fail)" >> "$log_file"
        else
            # Check container status
            local container_status=$(docker inspect -f '{{.State.Status}}' aztec-sequencer 2>/dev/null)
            if [ "$container_status" != "running" ]; then
                fail_count=$((fail_count+1))
                echo -e "${RED}Aztec node container not healthy - status: $container_status ($fail_count/$max_fail) at $(date)${NC}"
                echo "[WARN] Container not healthy at $(date) - status: $container_status ($fail_count/$max_fail)" >> "$log_file"
            else
                fail_count=0
                echo -e "${GREEN}Aztec node container healthy at $(date)${NC}"
                echo "[OK] Container healthy at $(date)" >> "$log_file"
            fi
        fi
        if [ "$fail_count" -ge "$max_fail" ]; then
            echo -e "${RED}Aztec node unhealthy for $max_fail checks. Restarting...${NC}"
            echo "[ACTION] Restarting node at $(date)" >> "$log_file"
            cd ~ && cd "$aztec_dir" && docker compose down && docker compose up -d
            fail_count=0
            echo -e "${GREEN}Restarted Aztec node at $(date)${NC}"
            echo "[INFO] Node restarted at $(date)" >> "$log_file"
        fi
        sleep $interval
    done
}

# Function to start/stop health monitor in background
manage_aztec_health_monitor() {
    local monitor_pid_file="$AZTEC_DIR/.health_monitor.pid"
    while true; do
        echo -e "\n${BLUE}Aztec Node Health Monitor:${NC}"
        echo "1) Start auto restart node (background)"
        echo "2) Stop auto restart node"
        echo "3) Show monitor log"
        echo "0) Back to main menu"
        read -p "Enter your choice: " hmon_choice
        case $hmon_choice in
            1)
                if [ -f "$monitor_pid_file" ] && kill -0 $(cat "$monitor_pid_file") 2>/dev/null; then
                    echo -e "${YELLOW}Health monitor is already running (PID: $(cat $monitor_pid_file))${NC}"
                else
                    nohup bash -c 'monitor_aztec_health' &> "$AZTEC_DIR/health_monitor.log" &
                    echo $! > "$monitor_pid_file"
                    echo -e "${GREEN}Health monitor started in background (PID: $!)${NC}"
                fi
                ;;
            2)
                if [ -f "$monitor_pid_file" ] && kill -0 $(cat "$monitor_pid_file") 2>/dev/null; then
                    kill $(cat "$monitor_pid_file") && rm -f "$monitor_pid_file"
                    echo -e "${GREEN}Health monitor stopped.${NC}"
                else
                    echo -e "${YELLOW}No health monitor running.${NC}"
                fi
                ;;
            3)
                less +G "$AZTEC_DIR/health_monitor.log"
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid choice!${NC}"
                ;;
        esac
    done
}

# Main loop
while true; do
    if [ "$FIRST_RUN" = "true" ]; then
        show_welcome
        FIRST_RUN="false"
    fi
    show_menu
    read -p "Enter your choice: " choice
    
    case $choice in
        1)
            check_docker
            check_docker_compose
            setup_eth_node
            ;;
        2)
            setup_aztec_sequencer
            ;;
        3)
            control_services
            ;;
        4)
            view_logs
            ;;
        5)
            check_status
            ;;
        6)
            shell_access
            ;;
        7)
            buy_key
            ;;
        8)
            upgrade_sequencer
            ;;
        9)
            manage_governance_proposal
            ;;
        10)
            manage_env
            ;;
        11)
            configure_firewall
            ;;
        12)
            manage_services
            ;;
        13)
            export_peer_id
            ;;
        14)
            manage_aztec_health_monitor
            ;;
        99)
            factory_reset
            ;;
        0)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            read -p "Press Enter to continue..."
            ;;
    esac
done 
