#!/bin/bash

set -euo pipefail

project="$1"
SERVER_IP="$2"
SERVER_USER="$3"
SERVER_PORT="$4"
PRIVATE_KEY_CONTENT="$5"

remote_server="$SERVER_IP"
remote_share="/mnt/backups/$project"
local_mount="/mnt/backups/$project"
config_path="${local_mount}/full.yaml"
identity_file="$(mktemp /tmp/borg_key_$project)"
echo "$PRIVATE_KEY_CONTENT" > "$identity_file"
chmod 600 "$identity_file"

mkdir -p "$local_mount"

# Монтируем SSHFS
if ! sshfs -o IdentityFile="$identity_file",port="$SERVER_PORT",StrictHostKeyChecking=no "$SERVER_USER@$remote_server:$remote_share" "$local_mount"; then
    echo "Ошибка при монтировании SSHFS"
    rm -f "$identity_file"
    exit 1
fi

# Проверка существования конфигурации
if [[ ! -f "$config_path" ]]; then
    echo "Конфигурация $config_path не найдена."
    fusermount -u "$local_mount"
    rm -f "$identity_file"
    exit 1
fi

# Запуск borgmatic
if ! borgmatic --config "$config_path"; then
    echo "Ошибка при выполнении borgmatic"
    fusermount -u "$local_mount"
    rm -f "$identity_file"
    exit 1
fi

# Отмонтировать папку
fusermount -u "$local_mount"
rm -f "$identity_file"
