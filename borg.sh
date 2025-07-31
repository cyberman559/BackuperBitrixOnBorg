#!/bin/bash

function close() {
    fusermount -u "$local_mount"
    rm -f "$identity_file"
    rm -f "/home/bitrix/*.sql"
    #rm -rf "$local_mount"
}

project="$1"
SERVER_IP="$2"
SERVER_USER="$3"
SERVER_PORT="$4"
PRIVATE_KEY_CONTENT="$5"
shift 5

DB_NAME=("$@")

remote_server="$SERVER_IP"
remote_share="/mnt/backups/$project"
local_mount="/mnt/backups/$project"
config_path="${local_mount}/full.yaml"
identity_file="/tmp/borg_key_$project"

echo "$PRIVATE_KEY_CONTENT" | base64 -d > "$identity_file"
chmod 600 "$identity_file"

mkdir -p "$local_mount"

# Монтируем SSHFS
if ! sshfs -o IdentityFile="$identity_file",port="$SERVER_PORT",StrictHostKeyChecking=no "$SERVER_USER@$remote_server:$remote_share" "$local_mount"; then
    echo "Ошибка при монтировании SSHFS"
    close;
    exit 1
fi

# Проверка существования конфигурации
if [[ ! -f "$config_path" ]]; then
    echo "Конфигурация $config_path не найдена."
    close;
    exit 1
fi

dump_base_skip_stat=1
dump_base_skip_search=1
dump_base_skip_log=1

for db in "${DB_NAME[@]}"; do
    all_tables=($(mysql -N -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$db';"))

    IGNORE_ARGS=()

    for table in "${all_tables[@]}"; do
        table_lower=$(echo "$table" | tr '[:upper:]' '[:lower:]')

        # Проверка условий исключения
        if [[ $dump_base_skip_stat -eq 1 && "$table_lower" =~ ^b_stat ]]; then
            IGNORE_ARGS+=(--ignore-table="$db.$table")
            continue
        fi

        if [[ $dump_base_skip_search -eq 1 && "$table_lower" =~ ^b_search_ ]]; then
            if [[ ! "$table_lower" =~ ^b_search_custom_rank$ && ! "$table_lower" =~ ^b_search_phrase$ ]]; then
                IGNORE_ARGS+=(--ignore-table="$db.$table")
                continue
            fi
        fi

        if [[ $dump_base_skip_log -eq 1 && "$table_lower" == "b_event_log" ]]; then
            IGNORE_ARGS+=(--ignore-table="$db.$table")
            continue
        fi
    done

    mysqldump "${IGNORE_ARGS[@]}" "$db" > "/home/bitrix/$db.sql"
    if [[ $? -ne 0 ]]; then
        echo "Ошибка создания дампа базы данных."
        exit 1
    fi
done

# Запуск borgmatic
if ! borgmatic --config "$config_path"; then
    echo "Ошибка при выполнении borgmatic"
    close;
    exit 1
fi

close;