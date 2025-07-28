#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Запусти скрипт с правами root."
  exit 1
fi

read -p "Введите имя пользователя: " username

if id "$username" &>/dev/null; then
  echo "Пользователь $username уже существует."
else
  useradd -m "$username"
  echo "Пользователь $username создан."
fi

read -s -p "Введите пароль для пользователя $username: " password
echo
read -s -p "Подтвердите пароль: " password_confirm
echo

if [[ "$password" != "$password_confirm" ]]; then
  echo "Пароли не совпадают. Выход."
  exit 1
fi

echo "$username:$password" | chpasswd
echo "Пароль установлен."

# Добавляем пользователя в группу borg, удаляем из группы users
usermod -aG borg "$username"
gpasswd -d "$username" users

backup_dir="/mnt/backups/$username"
mkdir -p "$backup_dir"
chown "$username":"$username" "$backup_dir"

read -p "Введите имя пользователя Samba: " username_samba
mkdir ./users
cred_file="./users/.cifs_${username_samba}_cred"
echo "username=$username_samba" >> "$cred_file"

read -s -p "Введите пароль пользователя Samba: " password_samba
echo "password=$password_samba" >> "$cred_file"
chmod 600 "$cred_file"

mount_point="$backup_dir"
share="//192.168.6.3/$username"

uid=$(id -u $username)
gid=$(id -g $username)

mount -t cifs "$share" "$mount_point" -o username=$username_samba,password=$password_samba,uid=$uid,gid=$gid,vers=1.0

if [[ $? -ne 0 ]]; then
  echo "Ошибка при монтировании CIFS."
  exit 1
fi
echo "Папка примонтирована."

fstab_entry="$share $mount_point cifs credentials=$cred_file,uid=$uid,gid=$gid,vers=1.0 0 0"

grep -qF "$share" /etc/fstab || echo "$fstab_entry" >> /etc/fstab

echo "Завершено!"