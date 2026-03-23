#!/usr/bin/env bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "[1/5] Install Docker + unzip"
apt-get update -y
apt-get install -y ca-certificates curl gnupg unzip

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

echo "[2/5] Download crAPI"
cd /opt
curl -L -o /opt/crapi.zip https://github.com/OWASP/crAPI/archive/refs/heads/main.zip
unzip -o /opt/crapi.zip
cd /opt/crAPI-main/deploy/docker

echo "[3/5] Pull crAPI images"
docker compose pull

echo "[4/5] Start crAPI"
LISTEN_IP="0.0.0.0" docker compose -f docker-compose.yml --compatibility up -d

echo "[5/5] Wait for health endpoint"
for i in $(seq 1 60); do
  if curl -fsS http://localhost:8888/health; then
    echo "crAPI is healthy"
    exit 0
  fi
  echo "waiting for crAPI..."
  sleep 10
done

echo "crAPI did not become healthy in time"
docker compose ps || true
docker ps || true
exit 1