#!/bin/bash

source ./setting.conf

export BORG_RSH="ssh -i ~/.ssh/id_ed25519_borg -p $SSH_PORT"
export BORG_REMOTE_PATH="borg"

FLAG_FILE="$HOME/.full_last_success"
ARCHIVE_PREFIX="backup-nocore"

function server_is_up() {
    ssh -i ~/.ssh/id_ed25519_borg -o ConnectTimeout=5 -p "$SSH_PORT" "$SSH_USER@$SERVER_IP" "exit" &>/dev/null
}

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

function record_success() {
    date +%F > "$FLAG_FILE"
}

function create_backup() {
    ARCHIVE_NAME="${ARCHIVE_PREFIX}-$(date +%Y-%m-%d_%H-%M-%S)"
    borg create --verbose --stats --compression=lz4 \
        --exclude-from nocore_excludes \
        "$BORG_REPO"::"$ARCHIVE_NAME" "$BACKUP_SRC"
}

function prune_archives() {
    borg prune -a "${ARCHIVE_PREFIX}-*" \
        --keep-within=3d \
        --verbose "$BORG_REPO"
}

function create_db_dump() {
    all_tables=($(mysql -N -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DB_NAME';"))

    IGNORE_ARGS=()

    for table in "${all_tables[@]}"; do
        table_lower=$(echo "$table" | tr '[:upper:]' '[:lower:]')

        # Проверка условий исключения
        if [[ $dump_base_skip_stat -eq 1 && "$table_lower" =~ ^b_stat ]]; then
            IGNORE_ARGS+=(--ignore-table="$DB_NAME.$table")
            continue
        fi

        if [[ $dump_base_skip_search -eq 1 && "$table_lower" =~ ^b_search_ ]]; then
            if [[ ! "$table_lower" =~ ^b_search_custom_rank$ && ! "$table_lower" =~ ^b_search_phrase$ ]]; then
                IGNORE_ARGS+=(--ignore-table="$DB_NAME.$table")
                continue
            fi
        fi

        if [[ $dump_base_skip_log -eq 1 && "$table_lower" == "b_event_log" ]]; then
            IGNORE_ARGS+=(--ignore-table="$DB_NAME.$table")
            continue
        fi
    done

    mysqldump "${IGNORE_ARGS[@]}" "$DB_NAME" > "$DUMP_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Ошибка создания дампа базы данных."
        return 1
    fi
    echo "Дамп базы данных сохранён в $DUMP_FILE"
    return 0
}

function cleanup_db_dump() {
    rm -f "$DUMP_FILE"
}

# --- Основная логика ---

if server_is_up; then
    if time_to_backup; then
        echo "Сервер доступен, создаём резервную копию..."
        create_db_dump
        if create_backup; then
            echo "Резервная копия успешно создана."
            record_success
            prune_archives
            cleanup_db_dump
        else
            echo "Ошибка создания резервной копии."
        fi
    else
        echo "Резервная копия была менее 1 дня назад. Пропускаем."
    fi
else
    echo "Сервер недоступен. Ничего не делаем."
fi