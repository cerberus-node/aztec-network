## 🚀 Upgrade via Script (Docker)

### 📜 One-Line Upgrade Script

You can upgrade using this single-line command :

```bash
 bash <(curl -s https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/auto-upgrade.sh)
```

We provide a script that:

* Backs up your `docker-compose.yml`
* Updates the image tag to the latest version
* Removes the old database
* Pulls the new image
* Restarts your container
