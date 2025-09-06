#!/bin/bash

project="${1:-}"
if [[ -z "$project" ]]; then
    echo "Не передан параметр project"
    exit 1
fi

FLAG_FILE="/mnt/backups/${project}/.full_last_success"
FLAG_RUN="/mnt/backups/${project}/.run"

if [ -f "$FLAG_RUN" ]; then
    echo "Резервная копия уже выполняется"
    exit 0
fi

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

source /root/.borg/projects/${project}/settings.conf

if time_to_backup; then
    date +%F > "$FLAG_RUN"
    trap 'rm -f "$FLAG_RUN"' EXIT

    PRIVATE_KEY_PATH="/home/$project/.ssh/id_ed25519"
    PRIVATE_KEY_CONTENT=$(base64 -w0 "$PRIVATE_KEY_PATH")

    YAML="/root/.borg/projects/${project}/full.yaml"
    YAML_CONTENT=$(base64 -w0 "$YAML")

    set -e
    ssh -p "$PORT" -i /root/.ssh/id_ed25519 \
    "$USER@$IP" \
    BORG_PASSPHRASE="$BORG_PASSPHRASE" bash -s -- "$project" "$SERVER_IP" "$SERVER_USER" "$SERVER_PORT" "$PRIVATE_KEY_CONTENT" "$YAML_CONTENT" "${DB_NAME[@]}" < /root/.borg/borg.sh
    date +%F > "$FLAG_FILE"
else
    echo "Резервная копия была менее 1 дня назад. Пропускаем."
fi