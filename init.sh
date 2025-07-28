#!/bin/bash

source ./setting.conf

dnf install borgbackup -y

export BORG_RSH="ssh -i ~/.ssh/id_ed25519_borg -p $SSH_PORT"
borg init --encryption=none $BORG_REPO