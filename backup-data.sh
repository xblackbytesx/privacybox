#! /bin/bash

TIMESTAMP=$(date +"%Y%m%d-%H")
WORKING_DIR=$(pwd)
SERVER_NAME=$(hostname)
BACKUP_USER=$(echo "$USER")
BACKUP_DIR="/media/storage/backup/$SERVER_NAME/$TIMESTAMP"

# Backup host-machine cronjob tasks
mkdir -p "$BACKUP_DIR/cronjobs"
sudo crontab -l >> $BACKUP_DIR/cronjobs/root.txt
crontab -l >> $BACKUP_DIR/cronjobs/$USER.txt

# Copy the used backup-script into the backup folder
cp -p $WORKING_DIR/backup-data.sh $BACKUP_DIR/

sudo cp -Rp /media/storage/docker

# chown -R www-data:www-data $BACKUP_DIR

# sudo -u www-data php -f /var/www/nextcloud/occ files:scan --path="/$BACKUP_USER/files/backups/$SERVER_NAME"