#!/bin/bash

# 🚀 Fusaka Supernode Update Script
# Cập nhật Prysm lên version hỗ trợ supernode cho Fusaka upgrade

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SEPOLIA_DIR="$HOME/sepolia-node"

echo -e "${BLUE}🚀 Fusaka Supernode Update Script${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  FUSAKA SEPOLIA UPGRADE TRONG 17 GIỜ!${NC}"
echo -e "${YELLOW}   Cần cập nhật Prysm thành supernode${NC}"
echo ""

# Function to check if directory exists
check_directory() {
    if [ ! -d "$SEPOLIA_DIR" ]; then
        echo -e "${RED}❌ Sepolia node directory not found at $SEPOLIA_DIR${NC}"
        exit 1
    fi
}

# Function to backup current config
backup_config() {
    echo -e "${BLUE}📁 Creating backup...${NC}"
    cp "$SEPOLIA_DIR/docker-compose.yml" "$SEPOLIA_DIR/docker-compose.yml.backup.$(date +%Y%m%d-%H%M%S)"
    echo -e "${GREEN}✅ Backup created${NC}"
}

# Function to update Prysm to latest version
update_prysm() {
    echo -e "${BLUE}🔄 Updating Prysm to latest version...${NC}"
    
    cd "$SEPOLIA_DIR"
    
    # Stop containers
    echo -e "${YELLOW}🛑 Stopping containers...${NC}"
    docker compose down
    
    # Pull latest images
    echo -e "${YELLOW}⬇️  Pulling latest images...${NC}"
    docker compose pull
    
    # Update docker-compose.yml to use specific version
    echo -e "${YELLOW}⚙️  Updating configuration...${NC}"
    
    # Check if supernode parameter exists
    if ! grep -q "subscribe-all-data-subnets" docker-compose.yml; then
        echo -e "${YELLOW}➕ Adding supernode parameter...${NC}"
        
        # Add supernode parameter to Prysm command
        sed -i.bak '/--grpc-gateway-port=3500/a\
      --subscribe-all-data-subnets' docker-compose.yml
    fi
    
    # Start containers
    echo -e "${YELLOW}🚀 Starting containers...${NC}"
    docker compose up -d
    
    # Wait for startup
    sleep 10
    
    # Check status
    echo -e "${YELLOW}📊 Checking status...${NC}"
    docker compose ps
}

# Function to verify supernode configuration
verify_supernode() {
    echo -e "${BLUE}🔍 Verifying supernode configuration...${NC}"
    
    cd "$SEPOLIA_DIR"
    
    # Check if parameter is in config
    if grep -q "subscribe-all-data-subnets" docker-compose.yml; then
        echo -e "${GREEN}✅ Supernode parameter found in config${NC}"
    else
        echo -e "${RED}❌ Supernode parameter NOT found in config${NC}"
        return 1
    fi
    
    # Check Prysm logs for supernode
    echo -e "${YELLOW}📄 Checking Prysm logs...${NC}"
    docker compose logs prysm --tail=10 | grep -i "supernode\|subscribe\|data" || echo -e "${YELLOW}⚠️  No supernode logs found yet${NC}"
    
    # Check if Prysm is running
    if docker compose ps | grep -q "prysm.*Up"; then
        echo -e "${GREEN}✅ Prysm is running${NC}"
    else
        echo -e "${RED}❌ Prysm is not running properly${NC}"
        return 1
    fi
}

# Function to show monitoring commands
show_monitoring() {
    echo -e "${BLUE}📊 Monitoring Commands:${NC}"
    echo ""
    echo -e "${YELLOW}Check status:${NC}"
    echo -e "${BLUE}  cd $SEPOLIA_DIR && docker compose ps${NC}"
    echo ""
    echo -e "${YELLOW}Check Prysm logs:${NC}"
    echo -e "${BLUE}  cd $SEPOLIA_DIR && docker compose logs -f prysm${NC}"
    echo ""
    echo -e "${YELLOW}Check Geth logs:${NC}"
    echo -e "${BLUE}  cd $SEPOLIA_DIR && docker compose logs -f geth${NC}"
    echo ""
    echo -e "${YELLOW}Check sync status:${NC}"
    echo -e "${BLUE}  curl -s http://localhost:3500/eth/v1/node/syncing | jq${NC}"
    echo ""
}

# Function to show summary
show_summary() {
    echo -e "${BLUE}📋 Update Summary${NC}"
    echo -e "${BLUE}================${NC}"
    echo ""
    echo -e "${GREEN}✅ Prysm updated to latest version${NC}"
    echo -e "${GREEN}✅ Supernode parameter added${NC}"
    echo -e "${GREEN}✅ Containers restarted${NC}"
    echo ""
    echo -e "${YELLOW}📅 Fusaka Sepolia Upgrade: ~17 hours${NC}"
    echo -e "${YELLOW}📅 Fusaka Mainnet: December 3, 2025${NC}"
    echo ""
    echo -e "${BLUE}🔧 Next Steps:${NC}"
    echo -e "${BLUE}  1. Monitor node for the next few hours${NC}"
    echo -e "${BLUE}  2. Check sync status regularly${NC}"
    echo -e "${BLUE}  3. Prepare for Fusaka upgrade${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Remember: Supernode stores full blobs for PeerDAS!${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting Fusaka supernode update...${NC}"
    echo ""
    
    # Pre-flight checks
    check_directory
    
    # Confirm update
    echo -e "${YELLOW}⚠️  This will update Prysm to support supernode for Fusaka.${NC}"
    echo -e "${YELLOW}   A backup will be created before making changes.${NC}"
    echo ""
    read -p "Do you want to proceed with the supernode update? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Update cancelled.${NC}"
        exit 0
    fi
    
    # Execute update steps
    backup_config
    echo ""
    
    update_prysm
    echo ""
    
    verify_supernode
    echo ""
    
    show_monitoring
    echo ""
    
    show_summary
}

# Run main function
main "$@"
