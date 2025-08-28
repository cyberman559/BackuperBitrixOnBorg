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

export BORG_PASSPHRASE=${BORG_PASSPHRASE}

if time_to_backup; then
    date +%F > "$FLAG_RUN"
    trap 'rm -f "$FLAG_RUN"' EXIT

    ssh -p "$PORT" -i /root/.ssh/id_ed25519 "$USER@$IP" \
    DB_NAME="${DB_NAME[*]}" bash -s <<'EOF'
        dump_base_skip_stat=1
        dump_base_skip_search=1
        dump_base_skip_log=1

        IFS=' ' read -r -a DB_NAME <<< "$DB_NAME"

        for db in "${DB_NAME[@]}"; do
            all_tables=($(mysql -N -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$db';"))

            IGNORE_ARGS=()

            for table in "${all_tables[@]}"; do
                table_lower=$(echo "$table" | tr '[:upper:]' '[:lower:]')

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
            mkdir -p /home/bitrix/db_dumps
            mysqldump "${IGNORE_ARGS[@]}" "$db" > "/home/bitrix/db_dumps/$db.sql"
            if [[ $? -ne 0 ]]; then
                echo "Ошибка создания дампа базы данных."
            fi
        done
EOF

    mkdir -p /mnt/${project}
    sshfs -p "$PORT" -o IdentityFile=/root/.ssh/id_ed25519 "$USER@$IP":/home/bitrix /mnt/${project}

    borgmatic --config /root/.borg/projects/${project}/full.yaml --verbosity 1
    fusermount -u /mnt/${project}
else
    echo "Резервная копия была менее 1 дня назад. Пропускаем."
fi