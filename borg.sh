#!/bin/bash

set -euo pipefail

project="${1:-}"
if [[ -z "$project" ]]; then
    echo "Не передан параметр project"
    exit 1
fi

source "/root/sbp/projects/${project}/setting.conf"

remote_server="$SERVER_IP"
remote_share="/mnt/backups/${project}"
local_mount="/mnt/server_backup/${project}"
config_path="${local_mount}/full.yaml"
identity_file="/home/${project}/.ssh/id_ed25519_borg"

mkdir -p "$local_mount"

# Монтируем SSHFS
if ! sshfs -o IdentityFile="$identity_file",port="$SERVER_PORT",StrictHostKeyChecking=no "$SERVER_USER@$remote_server:$remote_share" "$local_mount"; then
    echo "Ошибка при монтировании SSHFS"
    exit 1
fi

# Проверка существования конфигурации
if [[ ! -f "$config_path" ]]; then
    echo "Конфигурация $config_path не найдена."
    fusermount -u "$local_mount"
    exit 1
fi

# Запуск borgmatic
if ! borgmatic --config "$config_path"; then
    echo "Ошибка при выполнении borgmatic"
    fusermount -u "$local_mount"
    exit 1
fi

# Отмонтировать папку
fusermount -u "$local_mount"