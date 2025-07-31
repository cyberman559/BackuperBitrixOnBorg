#!/bin/bash

project="${1:-}"
if [[ -z "$project" ]]; then
    echo "Не передан параметр project"
    exit 1
fi

FLAG_FILE="/mnt/backups/${project}/.full_last_success"

function time_to_backup() {
    if [[ ! -f "$FLAG_FILE" ]]; then
        return 0
    fi

    last_date=$(<"$FLAG_FILE")
    last_ts=$(date -d "$last_date" +%s)
    next_ts=$(date -d "$last_date +1 days" +%s)
    today_ts=$(date -d "$(date +%F)" +%s)

    if [ "$today_ts" -ge "$next_ts" ]; then
        return 0
    else
        return 1
    fi
}

source /root/sbp/projects/${project}/setting.conf

if time_to_backup; then
    PRIVATE_KEY_PATH="/home/$project/.ssh/id_ed25519_borg"
    PRIVATE_KEY_CONTENT=$(base64 -w0 "$PRIVATE_KEY_PATH")

    ssh -p "$CLIENT_PORT" -i /root/.ssh/id_ed25519_borg \
    "$CLIENT_USER@$CLIENT_IP" \
    BORG_PASSPHRASE="$BORG_PASSPHRASE" bash -s -- "$project" "$SERVER_IP" "$SERVER_USER" "$SERVER_PORT" "$PRIVATE_KEY_CONTENT" "${DB_NAME[@]}" < /root/sbp/borg.sh

else
    echo "Резервная копия была менее 1 дня назад. Пропускаем."
fi