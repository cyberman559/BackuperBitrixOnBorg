#!/bin/bash

source /root/sbp/projects/${project}/setting.conf

remote_server="${SSH_CONNECTION}"
remote_share="/mnt/backups/${project}"
local_mount="/mnt/server_backup/${project}"
config_path="${local_mount}/full.yaml"

mkdir -p "$local_mount"

sshfs -o IdentityFile=/root/.ssh/id_ed25519_borg,port=22,StrictHostKeyChecking=no "${SSH_USER:-root}@${remote_server}:${remote_share}" "$local_mount"

if [[ ! -f "$config_path" ]]; then
    echo "Конфигурация $config_path не найдена."
    fusermount -u "$local_mount"
    exit 1
fi

borgmatic --config "$config_path"

fusermount -u "$local_mount"

exit