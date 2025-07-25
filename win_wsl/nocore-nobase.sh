#!/bin/bash

source ../setting.conf

# SSH + WSL + borg
export BORG_RSH="ssh -p $SSH_PORT"
export BORG_REMOTE_PATH="/mnt/c/Users/lencode/wsl-borg.cmd"

# Источник для бэкапа
BACKUP_SRC="/home/bitrix/www"
EXCLUDE_PATH="bitrix"

# Контроль интервала между бэкапами
FLAG_FILE="$HOME/.nocore_nobase_last_success"
MAX_INTERVAL=$((24*3600))  # 24 часа

# Название архивов
ARCHIVE_PREFIX="backup-nocore-nobase"

function server_is_up() {
    ssh -o ConnectTimeout=5 -p "$SSH_PORT" "$SSH_USER@$SERVER_IP" "exit" &>/dev/null
}

function time_to_backup() {
    if [[ ! -f "$FLAG_FILE" ]]; then
        return 0
    fi
    last_ts=$(<"$FLAG_FILE")
    now_ts=$(date +%s)
    (( now_ts - last_ts >= MAX_INTERVAL ))
}

function record_success() {
    date +%s > "$FLAG_FILE"
}

function create_backup() {
    ARCHIVE_NAME="${ARCHIVE_PREFIX}$(date +%Y-%m-%d_%H-%M-%S)"
    borg create --verbose --stats --compression=lz4 \
        --exclude "$BACKUP_SRC/$EXCLUDE_PATH" \
        "$BORG_REPO"::"$ARCHIVE_NAME" "$BACKUP_SRC"
}

function prune_archives() {
    borg prune --prefix "$ARCHIVE_PREFIX" --keep-daily=3 --verbose "$BORG_REPO"
}

# --- Основная логика ---

if server_is_up; then
    if time_to_backup; then
        echo "Сервер доступен, создаём резервную копию..."
        create_backup
        if [[ $? -eq 0 ]]; then
            echo "Резервная копия успешно создана."
            record_success
            prune_archives
        else
            echo "Ошибка создания резервной копии."
        fi
    else
        echo "Резервная копия делалась менее суток назад. Пропускаем."
    fi
else
    echo "Сервер недоступен. Ничего не делаем."
fi
