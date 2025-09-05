#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "Запусти скрипт с правами root."
  exit 1
fi

read -p "Введите имя пользователя: " username

if id "$username" &>/dev/null; then
  echo "Пользователь $username уже существует."
else
  useradd -m -s /usr/sbin/nologin "$username"
  echo "Пользователь $username создан."
fi

backup_dir="/mnt/backups/$username"
mkdir -p "$backup_dir"
chown "$username":"$username" "$backup_dir"

set +e
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -C "borg"
set -e
echo "Публичный ключ:"
cat /root/.ssh/id_ed25519.pub
read -p "Добавьте его на клиент. Нажмите Enter, чтобы продолжить..."

ssh_dir="/home/$username/.ssh"
mkdir -p "$ssh_dir"
ssh-keygen -t ed25519 -f $ssh_dir/id_ed25519 -C "borg_client"

chown root:root "$ssh_dir"
chmod 700 "$ssh_dir"
touch "$ssh_dir/authorized_keys"
chown root:root "$ssh_dir/authorized_keys"
chmod 600 "$ssh_dir/authorized_keys"

echo "command=\"borg serve --restrict-to-path $backup_dir\",restrict $(cat $ssh_dir/id_ed25519.pub)" >> "$ssh_dir/authorized_keys"

systemctl restart sshd

if borg list $backup_dir > /dev/null 2>&1; then
  echo "Репозиторий уже инициализирован."
else
  borg init --encryption=repokey $backup_dir
  echo "Репозиторий создан."
fi

mkdir /root/.borg/projects/$username

sed "s/{{PROJECT}}/$(printf %q "$username")/g" /root/.borg/full.yaml.example > /root/.borg/projects/$username/full.yaml
if [[ ! -f /root/.borg/projects/$username/settings.conf ]]; then
  cp /root/.borg/settings.conf.example /root/.borg/projects/$username/settings.conf
fi

echo "Не забудь исправить /root/.borg/projects/$username/full.yaml и /root/.borg/projects/$username/$username.conf"

echo "Завершено!"