#!/bin/bash
set -e

read -p "Введите название проекта: " PROJECT
read -p "Введите IP клиента: " IP
read -p "Введите имя пользователя клиента [root]: " USER
USER=${USER:-"root"}
read -p "Введите порт клиента [22]: " PORT
PORT=${PORT:-22}

mkdir -p /root/.borg/projects/${PROJECT}
mkdir -p /mnt/${PROJECT}

CONFIG_FILE="/root/.borg/projects/${PROJECT}/settings.conf"

cat > "$CONFIG_FILE" <<EOF
IP="$IP"
USER=$USER
PORT="$PORT"
PROJECT="${PROJECT}"
BORG_PASSPHRASE="${PROJECT}"
DB_NAME=("sitemanager")
EOF

cp "/root/.borg/full.yaml.example" "/root/.borg/projects/${PROJECT}/full.yaml"

mkdir -p /mnt/backups/${PROJECT}
borg init --encryption=repokey /mnt/backups/${PROJECT}

echo "#############################################################################################################"
echo "#"
echo "# /root/.borg/projects/${PROJECT}/full.yaml"
echo "#"
echo "# Добавьте публичный ключ на ${IP}"
cat /root/.ssh/id_ed25519.pub