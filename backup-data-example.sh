#! /bin/bash

###################################
## Compose environment variables ##
###################################
TIMESTAMP=$(date +"%Y%m%d-%H")
WORKING_DIR=$(pwd)
SERVER_NAME=$(hostname)
PEON_USER="johndoe"
BACKUP_DIR="/media/storage/backup/$TIMESTAMP"
DOCKER_DATA_DIR="/media/storage/docker"
PRIVACYBOX_DIR="/home/$PEON_USER/privacybox-docker"

mkdir -p $BACKUP_DIR

#################################
## Collect files for packaging ##
#################################

# Backup host-machine cronjob tasks
mkdir -p "$BACKUP_DIR/cronjobs"
crontab -l >> $BACKUP_DIR/cronjobs/root.txt
sudo -u $PEON_USER crontab -l >> $BACKUP_DIR/cronjobs/$PEON_USER.txt

# Collect 
cp -p $WORKING_DIR/backup-data.sh $BACKUP_DIR/
sudo cp -Rp $DOCKER_DATA_DIR $BACKUP_DIR/
sudo cp -Rp $PRIVACYBOX_DIR $BACKUP_DIR/

# Package into a tarball
sudo tar -czvf $BACKUP_DIR.tar.gz $BACKUP_DIR
sudo rm -rf $BACKUP_DIR

##############################
## Sync the package to NAS: ##
##############################
sudo rsync -avx $BACKUP_DIR/ nasi:/volume1/NetBackup/$SERVER_NAME/

if [ "$1" == "--install" ]; then
  sudo ln -s $PRIVACYBOX_DIR/backup-data.sh ~/backup-data.sh

  #write out current crontab
  crontab -l > mycron
  #echo new cron into cron file
  echo "0 3,15 * * * ~/backup-data.sh" >> mycron
  #install new cron file
  crontab mycron
  rm mycron
fi

