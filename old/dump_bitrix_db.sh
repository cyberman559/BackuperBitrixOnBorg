#!/bin/bash

DB_NAME="$1"

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