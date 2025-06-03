# 🚀 Aztec Sequencer Node Manager

A comprehensive management script for your Aztec Sequencer Node.

## 🤖 Telegram Bot Service

For additional services and support, use our Telegram bot:
👉 [@cerberus_service_bot](https://t.me/cerberus_service_bot)

The bot provides:
- RPC endpoint management
- Beacon node access
- Node monitoring
- Technical support
- Community updates

> 💡 **Tip**: Use the Telegram bot to get reliable RPC endpoints instead of running your own Geth + Beacon nodes, especially if you have limited resources.

## 📥 Installation

```bash
# Single command installation
curl -sL https://raw.githubusercontent.com/cerberus-node/aztec-network/main/aztec-node-manager.sh -o aztec-node-manager.sh && chmod +x aztec-node-manager.sh && bash aztec-node-manager.sh
```

Or if you prefer to download and run separately:
```bash
# Download the script
curl -sL https://raw.githubusercontent.com/cerberus-node/aztec-network/main/aztec-node-manager.sh -o aztec-node-manager.sh

# Make it executable
chmod +x aztec-node-manager.sh

# Run the script
./aztec-node-manager.sh
```

## 🎮 Features

The script provides a user-friendly menu interface with the following options:

1. **Setup Geth + Beacon Node**
   - Automated setup of Geth execution client
   - Automated setup of Beacon consensus client
   - Automatic configuration of RPC endpoints

2. **Setup Aztec Sequencer**
   - Creates necessary directories
   - Sets up environment variables
   - Configures Docker container
   - Starts the sequencer node

3. **Control Services**
   - Start/Stop Geth
   - Start/Stop Beacon Node
   - Start/Stop Aztec Sequencer

4. **View Logs**
   - View Geth logs
   - View Beacon Node logs
   - View Aztec Sequencer logs

5. **Node Status**
   - Check sync status
   - Monitor node health
   - Compare with network height

6. **Shell Access**
   - Access Geth container shell
   - Access Beacon Node container shell
   - Access Aztec Sequencer container shell

7. **Buy RPC/Beacon Key**
   - Purchase RPC endpoints
   - Purchase Beacon endpoints
   - Manage your keys

8. **Upgrade Sequencer Node**
   - List available versions
   - Select and upgrade to new version
   - Automatic container restart

9. **Manage Governance Proposal**
   - Add/Edit governance address
   - Remove governance address
   - Verify governance settings
   - Check governance logs

10. **Manage Environment Variables**
    - View current settings
    - Edit variables
    - Add/Remove variables
    - Create from template

## 🔧 System Requirements

### Full Setup (Geth + Beacon + Aztec)
| Component | Recommended | Minimum |
|-----------|-------------|---------|
| CPU       | 8 cores     | 6 cores |
| RAM       | 32 GB       | 16 GB   |
| Storage   | 1 TB SSD    | 800 GB SSD |
| OS        | Ubuntu 22.04 or later |
| Network   | 100 Mbps+ bandwidth |
| Disk I/O  | 5000+ IOPS |

### Aztec Sequencer Only
| Component | Recommended | Minimum |
|-----------|-------------|---------|
| CPU       | 4 cores     | 2 cores |
| RAM       | 16 GB       | 8 GB    |
| Storage   | 100 GB SSD  | 50 GB SSD |
| OS        | Ubuntu 22.04 or later |
| Network   | 50 Mbps+ bandwidth |
| Disk I/O  | 2000+ IOPS |

> ⚠️ **Note**: Running Geth + Beacon nodes locally requires significantly more resources than using external RPC endpoints. If you have limited resources, consider using external RPC providers instead of running your own nodes.

### Additional Requirements
- Docker and Docker Compose installed
- Public IP address
- Open ports: 40400 (TCP/UDP), 8080 (TCP)
- For Geth: Ports 30303 (TCP/UDP), 8545 (TCP)
- For Beacon: Ports 12000 (UDP), 13000 (TCP), 5052 (TCP)

## 📝 Quick Start

1. Download and run the script
2. Choose option 1 to setup Geth + Beacon Node
3. Choose option 2 to setup Aztec Sequencer
4. Follow the prompts to configure your node
5. Monitor your node using options 4 and 5

## 🔍 Monitoring

Use the following options to monitor your node:

- Option 4: View real-time logs
- Option 5: Check sync status and health
- Option 9: Verify governance settings

## 🔒 Security

- Private keys are stored in `.env` file
- Docker containers run in isolated environment
- Network ports are properly configured
- Regular updates available through option 8

## 🆘 Troubleshooting

If you encounter issues:

1. Check logs using option 4
2. Verify node status using option 5
3. Check governance settings using option 9
4. Restart services using option 3

## 🔄 Updates

The script can be updated by downloading the latest version:

```bash
curl -sL https://raw.githubusercontent.com/cerberus-node/aztec-network/main/aztec-node-manager.sh -o aztec-node-manager.sh
chmod +x aztec-node-manager.sh
```

## 📚 Additional Resources

- [Aztec Network Documentation](https://docs.aztec.network)
- [Discord Community](https://discord.gg/aztec)
- [GitHub Repository](https://github.com/cerberus-node/aztec-network)

## ⚠️ Disclaimer

This script is provided as-is. Always verify the script contents before running it on your system.

> 💾 **Storage Note**: 
> - Geth node requires ~500GB for Sepolia chain data
> - Beacon node requires ~200GB for consensus data
> - Aztec Sequencer requires ~100GB
> - Additional space needed for OS, logs, and future growth

