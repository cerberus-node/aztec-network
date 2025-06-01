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
    echo -e "${BLUE}    🦾 Aztec Sequencer Node Manager v1.0.0     ${NC}"
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
    sleep 2
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
        exit 1
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
    
    # Download setup script
    curl -sL https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/auto-setup-sepolia.sh -o "$NODE_DIR/auto-setup-sepolia.sh"
    chmod +x "$NODE_DIR/auto-setup-sepolia.sh"
    
    # Run setup script
    cd "$NODE_DIR" && ./auto-setup-sepolia.sh

    # Configure firewall for Geth and Beacon
    setup_firewall_ports "geth"
    setup_firewall_ports "beacon"

    # Save RPC and Beacon URLs for later use
    local rpc_url="http://localhost:8545"
    local beacon_url="http://localhost:5052"
    save_config "ETH_RPC_URL" "$rpc_url"
    save_config "ETH_BEACON_URL" "$beacon_url"
    
    echo -e "${GREEN}Geth + Beacon Node setup completed!${NC}"
    echo -e "${GREEN}RPC URL: $rpc_url${NC}"
    echo -e "${GREEN}Beacon URL: $beacon_url${NC}"
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
    
    read -p "🔑 Enter your Ethereum Private Key (0x...): " VALIDATOR_PRIVATE_KEY
    read -p "🏦 Enter your Ethereum Address (0x...): " VALIDATOR_ADDRESS
    
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
VALIDATOR_PRIVATE_KEY=$VALIDATOR_PRIVATE_KEY
VALIDATOR_ADDRESS=$VALIDATOR_ADDRESS
P2P_IP=$P2P_IP
EOF
    echo "✅ .env file created."
    
    # Create docker-compose.yml
    cat <<EOF > docker-compose.yml
services:
  aztec-node:
    container_name: aztec-sequencer
    image: aztecprotocol/aztec:0.87.2
    restart: unless-stopped
    environment:
      ETHEREUM_HOSTS: \${ETHEREUM_HOSTS}
      L1_CONSENSUS_HOST_URLS: \${L1_CONSENSUS_HOST_URLS}
      VALIDATOR_PRIVATE_KEY: \${VALIDATOR_PRIVATE_KEY}
      P2P_IP: \${P2P_IP}
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
            cd ~ && cd "$NODE_DIR" && docker compose logs -f prysm
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
    echo -e "${YELLOW}Checking node status (Sync Status & Endpoint Health)...${NC}"
    
    # Check Geth RPC Health & Sync Status
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "\n${BLUE}Geth Status:${NC}"
        curl -s -X POST http://localhost:8545 \
            -H 'Content-Type: application/json' \
            -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | jq
        
        echo -e "\n${BLUE}Beacon Node Status:${NC}"
        curl -s http://localhost:5052/eth/v1/node/syncing | jq
        curl -s http://localhost:5052/eth/v1/node/health | jq # Add Beacon Health check here
    else
        echo -e "${RED}ETH Node not set up yet.${NC}"
    fi
    
    # Check Aztec Sequencer sync status (block tips)
    echo -e "\n${BLUE}Aztec Sequencer Sync Status:${NC}"
    LOCAL_AZTEC_PORT=8080
    LOCAL_AZTEC_RPC="http://localhost:$LOCAL_AZTEC_PORT"
    REMOTE_AZTEC_RPC="https://aztec-rpc.cerberusnode.com"

    # Check if local Aztec node is running
    if lsof -i :$LOCAL_AZTEC_PORT >/dev/null 2>&1; then
        LOCAL_RESPONSE=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
            -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$LOCAL_AZTEC_RPC")
        if [ -z "$LOCAL_RESPONSE" ] || [[ "$LOCAL_RESPONSE" == *"error"* ]]; then
            echo "❌ Local Aztec node not responding or returned an error. Please check if it's running on $LOCAL_AZTEC_RPC"
            LOCAL_BLOCK="N/A"
        else
            LOCAL_BLOCK=$(echo "$LOCAL_RESPONSE" | jq -r ".result.proven.number")
        fi
    else
        echo "⚠️ No Aztec node detected on port $LOCAL_AZTEC_PORT."
        LOCAL_BLOCK="N/A"
    fi

    REMOTE_RESPONSE=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$REMOTE_AZTEC_RPC")
    if [ -z "$REMOTE_RESPONSE" ] || [[ "$REMOTE_RESPONSE" == *"error"* ]]; then
        echo "⚠️ Remote Aztec RPC ($REMOTE_AZTEC_RPC) not responding or returned an error."
        REMOTE_BLOCK="N/A"
    else
        REMOTE_BLOCK=$(echo "$REMOTE_RESPONSE" | jq -r ".result.proven.number")
    fi

    echo "🧱 Local Aztec block:  $LOCAL_BLOCK"
    echo "🌐 Remote Aztec block: $REMOTE_BLOCK"

    if [[ "$LOCAL_BLOCK" == "N/A" ]] || [[ "$REMOTE_BLOCK" == "N/A" ]]; then
        echo "🚫 Cannot determine Aztec sync status due to an error in one of the RPC responses."
    elif [ "$LOCAL_BLOCK" = "$REMOTE_BLOCK" ]; then
        echo "✅ Aztec node is fully synced!"
    else
        echo "⏳ Aztec node is still syncing... ($LOCAL_BLOCK / $REMOTE_BLOCK)"
    fi
    
    read -p "Press Enter to continue..."
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
    echo -e "${YELLOW}Buying RPC/Beacon key... under maintenance${NC}"
    echo -e "${BLUE}Please visit our Telegram bot to purchase keys:${NC}"
    echo -e "${YELLOW}👉 https://t.me/cerberus_service_bot${NC}"
    echo -e "\n${GREEN}Benefits of using Cerberus Service:${NC}"
    echo -e "✅ Reliable RPC endpoints"
    echo -e "✅ High-performance Beacon nodes"
    echo -e "✅ 24/7 monitoring and support"
    echo -e "✅ Cost-effective solution"
    echo -e "✅ No need to run your own Geth + Beacon nodes"
    read -p "Press Enter to continue..."
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
VALIDATOR_PRIVATE_KEY=your_private_key_here
VALIDATOR_ADDRESS=your_validator_address_here
P2P_IP=your_public_ip

# Optional Configuration
LOG_LEVEL=debug
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