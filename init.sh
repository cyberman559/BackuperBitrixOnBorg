#!/bin/bash

source ./setting.conf

dnf install borgbackup -y

ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_borg -C "borg_$SSH_USER"
echo "Публичный ключ:"
cat ~/.ssh/id_ed25519_borg.pub
read -p "Нажмите Enter, чтобы продолжить..."

export BORG_RSH="ssh -i ~/.ssh/id_ed25519_borg -p $SSH_PORT"
borg init --encryption=none $BORG_REPO