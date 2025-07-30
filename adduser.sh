#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Запусти скрипт с правами root."
  exit 1
fi

read -p "Введите название проекта: " username

if id "$username" &>/dev/null; then
  echo "Пользователь проекта $username уже существует."
else
  useradd -M -s /usr/sbin/nologin "$username"
  echo "Пользователь проекта $username создан."
fi

# Добавляем пользователя в группу borg, удаляем из группы users
usermod -aG borg "$username"
gpasswd -d "$username" users

backup_dir="/mnt/backups/$username"
mkdir -p "$backup_dir"
chown "$username":"$username" "$backup_dir"

read -p "Введите имя пользователя Samba: " username_samba
cred_file="/root/sbp/.cifs_${username_samba}_cred"
#echo "username=$username_samba" >> "$cred_file"

read -s -p "Введите пароль пользователя Samba: " password_samba
#echo "password=$password_samba" >> "$cred_file"
#chmod 600 "$cred_file"

mount_point="$backup_dir"
share="//192.168.6.3/$username"

uid=$(id -u $username)
gid=$(id -g $username)

mount -t cifs "$share" "$mount_point" -o username="$username_samba",password="$password_samba",uid="$uid",gid="$gid",vers=1.0

if [[ $? -ne 0 ]]; then
  echo "Ошибка при монтировании CIFS."
  exit 1
fi
echo "Папка примонтирована."

fstab_entry="$share $mount_point cifs credentials=$cred_file,uid=$uid,gid=$gid,vers=1.0 0 0"

grep -qF "$share" /etc/fstab || echo "$fstab_entry" >> /etc/fstab

ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519_borg -C "borg"
echo "Публичный ключ:"
cat /root/.ssh/id_ed25519_borg.pub
read -p "Нажмите Enter, чтобы продолжить..."

borg init --encryption=repokey-blake2 /mnt/backups/$username

mkdir /root/sbp/projects
mkdir /root/sbp/projects/$username

cp /root/sbp/borgmatic/full.yaml /mnt/backups/$username/full.yaml
cp /root/sbp/conf/setting.conf /root/sbp/projects/$username/$username.conf

echo "Не забудь исправить /root/sbp/projects/$username/full.yaml и /root/sbp/conf/$username.conf"

echo "Завершено!"