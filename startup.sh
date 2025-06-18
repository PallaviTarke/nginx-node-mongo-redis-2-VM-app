#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose git
systemctl start docker
systemctl enable docker
usermod -aG docker pallavi
git clone https://github.com/PallaviTarke/nginx-node-mongo-redis-2-VM-app.git /app
chown -R pallavi:pallavi /app
chmod -R u+w /app
cd /app
export GCP_PROJECT_ID=project-pallavi-tarke
export GCP_BUCKET=mongobackupbucket
su - pallavi -c "docker-compose up -d"
