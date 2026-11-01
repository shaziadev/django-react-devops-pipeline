#!/usr/bin/env bash
# One-time setup for a fresh Ubuntu 22.04/24.04 EC2 instance.
# Run as the default "ubuntu" user:  bash ec2-bootstrap.sh
set -euo pipefail

APP_DIR=/opt/app

echo "==> Installing Docker Engine and the Compose plugin"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
# shellcheck disable=SC1091
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Letting $USER run docker without sudo"
sudo usermod -aG docker "$USER"

echo "==> Creating $APP_DIR"
sudo mkdir -p "$APP_DIR/scripts"
sudo chown -R "$USER":"$USER" "$APP_DIR"

echo "==> Basic firewall: SSH, HTTP, HTTPS"
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo
echo "Done. Next steps:"
echo "  1. Log out and back in (so the docker group applies)."
echo "  2. Create $APP_DIR/.env from .env.production.example."
echo "  3. Push to main once so GitHub Actions copies the compose file and scripts here."
echo "  4. Run: cd $APP_DIR && bash scripts/init-letsencrypt.sh"
