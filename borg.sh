#!/bin/bash

project="$1"
PRIVATE_KEY_CONTENT="$2"
YAML="$3"
shift 3

DB_NAME=("$@")

RANDOM_STRING=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
SALT="fgh56"
identity_file="/tmp/$RANDOM_STRING$SALT"
yaml_file="/tmp/$RANDOM_STRING$SALT.yaml"

function close() {
    rm -f "$identity_file"
    rm -f "$yaml_file"
}

trap close EXIT

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

    mysqldump "${IGNORE_ARGS[@]}" "$db" > "/home/bitrix/db_dumps/$db.sql"
    if [[ $? -ne 0 ]]; then
        echo "Ошибка создания дампа базы данных."
    fi
done

echo "$PRIVATE_KEY_CONTENT" | base64 -d > "$identity_file"
chmod 600 "$identity_file"

echo "$YAML" | base64 -d > "$yaml_file"
chmod 600 "$yaml_file"

# Проверка существования конфигурации
if [[ ! -f "$yaml_file" ]]; then
    echo "Конфигурация $yaml_file не найдена."
    exit 1
fi

export BORG_RSH="ssh -i $identity_file"
borgmatic --config "$yaml_file" --verbosity 1
if [[ $? -ne 0 ]]; then
    echo "Ошибка при запуске borgmatic для проекта ${project}"
    exit 1
fi

echo "Бэкап проекта ${project} успешно завершён."