#!/bin/bash

# Configuration
REMOTE_RPC="https://aztec-rpc.cerberusnode.com"
AZTECSCAN_API_KEY="temporary-api-key"
AZTECSCAN_API_URL="https://api.testnet.aztecscan.xyz/v1/$AZTECSCAN_API_KEY/l2/ui/blocks-for-table"
DEFAULT_PORT=8080
CHECK_INTERVAL=10
MAX_RETRIES=3

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to handle graceful exit
cleanup() {
    print_status $YELLOW "\n🛑 Sync check stopped by user"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Function to check if jq is installed
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        print_status $RED "❌ Error: jq is not installed. Please install it first:"
        echo "   macOS: brew install jq"
        echo "   Ubuntu/Debian: sudo apt-get install jq"
        echo "   CentOS/RHEL: sudo yum install jq"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        print_status $RED "❌ Error: curl is not installed. Please install it first."
        exit 1
    fi
}

# Function to get latest proven block from AztecScan API
get_latest_proven_block() {
    local BATCH_SIZE=20
    local FOUND=0

    # Get latest block height
    local LATEST_BLOCK=$(curl -s "$AZTECSCAN_API_URL?from=0&to=0" | jq -r '.[0].height')
    
    if [ -z "$LATEST_BLOCK" ] || [ "$LATEST_BLOCK" == "null" ]; then
        echo "N/A"
        return
    fi

    local CURRENT_HEIGHT=$LATEST_BLOCK

    # Search backwards for blockStatus = 4 (proven blocks)
    while [ $FOUND -eq 0 ]; do
        local FROM_HEIGHT=$((CURRENT_HEIGHT - BATCH_SIZE + 1))
        if [ $FROM_HEIGHT -lt 0 ]; then
            FROM_HEIGHT=0
        fi

        local RESPONSE=$(curl -s "$AZTECSCAN_API_URL?from=$FROM_HEIGHT&to=$CURRENT_HEIGHT")
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

# Function to calculate percentage
calculate_percentage() {
    local local_block=$1
    local remote_block=$2
    
    if [[ "$local_block" == "N/A" ]] || [[ "$remote_block" == "N/A" ]] || [[ "$remote_block" -eq 0 ]]; then
        echo "N/A"
    else
        local percentage=$(echo "scale=2; $local_block * 100 / $remote_block" | bc -l 2>/dev/null || echo "N/A")
        echo "$percentage"
    fi
}

# Function to format large numbers
format_number() {
    local num=$1
    if [[ "$num" == "N/A" ]]; then
        echo "N/A"
    else
        echo "$num" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'
    fi
}

# Function to get remote block with fallback
get_remote_block() {
    local remote_source=""
    
    # Try RPC first
    print_status $CYAN "🔍 Trying remote RPC: $REMOTE_RPC"
    local REMOTE_RESPONSE=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$REMOTE_RPC")
    
    if [ -n "$REMOTE_RESPONSE" ] && [[ "$REMOTE_RESPONSE" != *"error"* ]]; then
        local REMOTE_BLOCK=$(echo "$REMOTE_RESPONSE" | jq -r ".result.proven.number" 2>/dev/null)
        if [[ "$REMOTE_BLOCK" != "null" ]] && [[ "$REMOTE_BLOCK" != "N/A" ]]; then
            remote_source="RPC"
            echo "$REMOTE_BLOCK|$remote_source"
            return
        fi
    fi
    
    # Try AztecScan API as fallback
    print_status $YELLOW "⚠️ RPC failed, trying AztecScan API fallback..."
    local REMOTE_BLOCK=$(get_latest_proven_block)
    if [[ "$REMOTE_BLOCK" != "N/A" ]]; then
        remote_source="AztecScan"
        echo "$REMOTE_BLOCK|$remote_source"
        return
    fi
    
    echo "N/A|None"
}

# Check dependencies
check_dependencies

# Check if any app is running on default port
if lsof -i :$DEFAULT_PORT >/dev/null 2>&1; then
    print_status $GREEN "✅ Detected app running on port $DEFAULT_PORT"
    PORT=$DEFAULT_PORT
else
    print_status $YELLOW "⚠️ No app found on port $DEFAULT_PORT"
    read -p "Please enter your local Aztec RPC port (or press Enter for $DEFAULT_PORT): " USER_PORT
    PORT=${USER_PORT:-$DEFAULT_PORT}
fi

LOCAL_RPC="http://localhost:$PORT"

print_status $CYAN "🚀 Starting Aztec node sync monitor..."
print_status $BLUE "📍 Local RPC: $LOCAL_RPC"
print_status $BLUE "🌐 Remote RPC: $REMOTE_RPC"
print_status $BLUE "🔗 Fallback API: AztecScan"
print_status $BLUE "⏱️ Check interval: ${CHECK_INTERVAL}s"
echo ""

# Initialize counters
check_count=0
error_count=0

while true; do
    ((check_count++))
    current_time=$(date '+%Y-%m-%d %H:%M:%S')
    print_status $PURPLE "🔍 Check #$check_count - $current_time"

    # Check LOCAL node status with retry logic
    local_retry=0
    LOCAL_RESPONSE=""
    while [[ $local_retry -lt $MAX_RETRIES ]] && [[ -z "$LOCAL_RESPONSE" ]]; do
        LOCAL_RESPONSE=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
            -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' "$LOCAL_RPC" 2>/dev/null)
        if [[ -z "$LOCAL_RESPONSE" ]]; then
            ((local_retry++))
            if [[ $local_retry -lt $MAX_RETRIES ]]; then
                print_status $YELLOW "⚠️ Local node retry $local_retry/$MAX_RETRIES..."
                sleep 1
            fi
        fi
    done

    if [ -z "$LOCAL_RESPONSE" ] || [[ "$LOCAL_RESPONSE" == *"error"* ]]; then
        print_status $RED "❌ Local node not responding after $MAX_RETRIES retries. Please check if it's running on $LOCAL_RPC"
        LOCAL="N/A"
        ((error_count++))
    else
        LOCAL=$(echo "$LOCAL_RESPONSE" | jq -r ".result.proven.number" 2>/dev/null || echo "N/A")
        if [[ "$LOCAL" == "null" ]] || [[ "$LOCAL" == "N/A" ]]; then
            print_status $RED "❌ Failed to parse local block number from response"
            LOCAL="N/A"
            ((error_count++))
        fi
    fi

    # Get REMOTE block with fallback
    REMOTE_DATA=$(get_remote_block)
    REMOTE=$(echo "$REMOTE_DATA" | cut -d'|' -f1)
    REMOTE_SOURCE=$(echo "$REMOTE_DATA" | cut -d'|' -f2)

    if [[ "$REMOTE" == "N/A" ]]; then
        print_status $RED "❌ All remote sources failed after $MAX_RETRIES retries"
        ((error_count++))
    else
        print_status $GREEN "✅ Got remote block from $REMOTE_SOURCE: $REMOTE"
    fi

    # Format numbers for display
    LOCAL_DISPLAY=$(format_number "$LOCAL")
    REMOTE_DISPLAY=$(format_number "$REMOTE")

    echo ""
    print_status $CYAN "📊 Sync Status:"
    echo "   🧱 Local block:  $LOCAL_DISPLAY"
    echo "   🌐 Remote block: $REMOTE_DISPLAY (via $REMOTE_SOURCE)"

    # Calculate and display percentage
    PERCENTAGE=$(calculate_percentage "$LOCAL" "$REMOTE")
    if [[ "$PERCENTAGE" != "N/A" ]]; then
        echo "   📈 Progress:     ${PERCENTAGE}%"
    fi

    # Determine sync status
    if [[ "$LOCAL" == "N/A" ]] || [[ "$REMOTE" == "N/A" ]]; then
        print_status $RED "🚫 Cannot determine sync status due to connection errors"
        print_status $YELLOW "💡 Error count: $error_count (out of $check_count checks)"
    elif [ "$LOCAL" = "$REMOTE" ]; then
        print_status $GREEN "✅ Your node is fully synced!"
        error_count=0  # Reset error count on success
    else
        local_num=$(echo "$LOCAL" | tr -cd '0-9')
        remote_num=$(echo "$REMOTE" | tr -cd '0-9')
        
        if [[ "$local_num" =~ ^[0-9]+$ ]] && [[ "$remote_num" =~ ^[0-9]+$ ]]; then
            if [[ $local_num -gt $remote_num ]]; then
                print_status $GREEN "✅ Your node is ahead of the remote! (Local: $local_num, Remote: $remote_num)"
            else
                print_status $YELLOW "⏳ Still syncing... ($LOCAL_DISPLAY / $REMOTE_DISPLAY)"
                if [[ "$PERCENTAGE" != "N/A" ]]; then
                    local percentage_num=$(echo "$PERCENTAGE" | cut -d. -f1)
                    if [[ $percentage_num -gt 90 ]]; then
                        print_status $GREEN "🎉 Almost there! More than 90% synced!"
                    elif [[ $percentage_num -gt 50 ]]; then
                        print_status $CYAN "🚀 Good progress! More than 50% synced!"
                    fi
                fi
            fi
        else
            print_status $RED "❌ Invalid block numbers received"
        fi
    fi

    echo ""
    print_status $BLUE "📈 Statistics:"
    echo "   ✅ Successful checks: $((check_count - error_count))"
    echo "   ❌ Error count: $error_count"
    echo "   📊 Success rate: $(( (check_count - error_count) * 100 / check_count ))%"
    echo "   🔗 Last remote source: $REMOTE_SOURCE"
    
    echo ""
    print_status $PURPLE "⏰ Next check in ${CHECK_INTERVAL} seconds... (Press Ctrl+C to stop)"
    echo "----------------------------------------"
    sleep $CHECK_INTERVAL
done
