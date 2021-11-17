#!/bin/bash

# Example crontab user entry: 
# * * * * * . $HOME/.profile $HOME/privacybox-docker/manage.sh --vpncheck >/dev/null 2>&1

# Read config
. ./privacybox.config

###################################
## Compose environment variables ##
###################################
TIMESTAMP_MINUTE=$(date +"%Y%m%d-%H:%M")
TIMESTAMP_HOUR=$(date +"%Y%m%d-%H")

SERVER_NAME=$(cat /proc/sys/kernel/hostname)

# Defaults
DEPLOYED_APPS=( traefik portainer )

# Finding Docker binary
DOCKERPATH=$(which docker)
COMPOSEPATH=$(which docker-compose)

# Establishing privacybox dir locations
PRIVACYBOX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
DOCKER_DATA_DIR=$DOCKER_ROOT
BACKUP_DIR=$STORAGE_ROOT/backups


###############
## Bootstrap ##
###############
if ! [[ -f "./logs/privacybox.log" ]]
then
    mkdir logs
    touch logs/privacybox.log
fi

# Make scripts in scripts folder executable
chmod +x ./scripts/*.sh


###################
## Command flags ##
###################
if [ "$1" == "--provision" ]; then
    source scripts/provision.sh

elif [ "$1" == "--getcompose" ]; then
    echo "Installing latest docker-compose"
    sudo mv ${COMPOSEPATH} ${COMPOSEPATH}BAK${TIMESTAMP_MINUTE}
	sudo curl -L "https://github.com/docker/compose/releases/download/v2.1.1/docker-compose-$(uname -s)-$(uname -m)" -o ${COMPOSEPATH}
	sudo chmod +x ${COMPOSEPATH}
	echo "Succesfully installed $(${COMPOSEPATH} --version)"

elif [ "$1" == "--free-dsm-ports" ]; then
    source scripts/free-dsm-ports.sh

elif [ "$1" == "--start" ] || [ "$1" == "--stop" ] || [ "$1" == "--update" ]; then
    if [ "$2" == "--all" ]; then
        if [ -z ${DEPLOYED_APPS} ]; then 
            echo "No deployed apps are configured. Please check your privacybox.config file.";
        else

            if [ "$1" == "--start" ]; then
                for APP in "${DEPLOYED_APPS[@]}"
                do
                : 
                    cd ${PRIVACYBOX_DIR}/apps/$APP
                    ${COMPOSEPATH} up -d
                done

                echo "${TIMESTAMP_MINUTE} All services started manually" >> ${PRIVACYBOX_DIR}/logs/privacybox.log

            elif [ "$1" == "--stop" ]; then
                for APP in "${DEPLOYED_APPS[@]}"
                do
                : 
                    cd ${PRIVACYBOX_DIR}/apps/$APP
                    ${COMPOSEPATH} down -v
                done

                echo "${TIMESTAMP_MINUTE} All services stopped manually" >> ${PRIVACYBOX_DIR}/logs/privacybox.log

            elif [ "$1" == "--update" ]; then
                for APP in "${DEPLOYED_APPS[@]}"
                do
                : 
                    cd ${PRIVACYBOX_DIR}/apps/$APP
                    ${COMPOSEPATH} pull && ${COMPOSEPATH} up -d --build
                done

                echo "${TIMESTAMP_MINUTE} Updated all services" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
            fi

        fi

    elif [ "$2" == "--killswitch-apps" ]; then
        if [ -z ${KILLSWITCH_APPS} ]; then 
            echo "No killswitch apps are configured. Please check your privacybox.config file.";
        else    
            if [ "$1" == "--start" ]; then
                for APP in "${KILLSWITCH_APPS[@]}"
                do
                : 
                    cd ${PRIVACYBOX_DIR}/apps/$APP
                    ${COMPOSEPATH} up -d
                done

                echo "${TIMESTAMP_MINUTE} Killswitch services started manually" >> ${PRIVACYBOX_DIR}/logs/privacybox.log

            elif [ "$1" == "--stop" ]; then
                for APP in "${KILLSWITCH_APPS[@]}"
                do
                : 
                    cd ${PRIVACYBOX_DIR}/apps/$APP
                    ${COMPOSEPATH} down -v
                done

                echo "${TIMESTAMP_MINUTE} Killswitch services stopped manually" >> ${PRIVACYBOX_DIR}/logs/privacybox.log

            elif [ "$1" == "--update" ]; then
                for APP in "${KILLSWITCH_APPS[@]}"
                do
                : 
                    cd ${PRIVACYBOX_DIR}/apps/$APP
                    ${COMPOSEPATH} pull && ${COMPOSEPATH} up -d --build
                done

                echo "${TIMESTAMP_MINUTE} Updated killswitch services" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
            fi

        fi

    fi

elif [ "$1" == "--vpncheck" ]; then
    BASEIP=$("${DOCKERPATH}" run --rm alpine /usr/bin/wget -qO - ifconfig.me)
    VPNIP=$("${DOCKERPATH}" run --rm --network=container:expressvpn alpine /usr/bin/wget -qO - ifconfig.me)

    # # Additional debugging information
    # echo "BASEIP = ${BASEIP}" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
    # echo "VPNIP = ${VPNIP}" >> ${PRIVACYBOX_DIR}/logs/privacybox.log

    if [ "${VPNIP}" != "${BASEIP}" ]; then
        echo "${TIMESTAMP_MINUTE} VPN Up" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
        echo "${TIMESTAMP_MINUTE} Keeping services running" >> ${PRIVACYBOX_DIR}/logs/privacybox.log

        if [ -z ${KILLSWITCH_APPS} ]; then 
            echo "No Killswitch apps are configured. Please check your privacybox.config file.";
        else
            for APP in "${KILLSWITCH_APPS[@]}"
            do
            : 
                cd ${PRIVACYBOX_DIR}/apps/$APP
                ${COMPOSEPATH} up -d
            done
        fi

    elif [ "${VPNIP}" == "${BASEIP}" ]; then
        echo "${TIMESTAMP_MINUTE} VPN Down" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
        echo "${TIMESTAMP_MINUTE} Engaging killswitch" >> ${PRIVACYBOX_DIR}/logs/privacybox.log

        if [ -z ${KILLSWITCH_APPS} ]; then 
            echo "No Killswitch apps are configured. Please check your privacybox.config file.";
        else
            for APP in "${KILLSWITCH_APPS[@]}"
            do
            : 
                cd ${PRIVACYBOX_DIR}/apps/$APP
                ${COMPOSEPATH} down -v
            done
        fi

        echo "${TIMESTAMP_MINUTE} Issuing VPN restart" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
        cd ${PRIVACYBOX_DIR}/apps/expressvpn
        ${COMPOSEPATH} down -v
        ${COMPOSEPATH} up -d
    else
        echo "Unable to determine VPN status" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
    fi


elif [ "$1" == "--backup" ]; then
    mkdir -p $BACKUP_DIR
    sudo tar -zcvpf $BACKUP_DIR/$TIMESTAMP_HOUR-$SERVER_NAME.tar.gz $PRIVACYBOX_DIR $DOCKER_DATA_DIR

else
    echo "Please append one of the following flags to this command:"
    echo "--provision"
    echo "--getcompose"
    echo "--free-dsm-ports"
    echo "--start --all"
    echo "--start --killswitch-apps"
    echo "--stop --all"
    echo "--stop --killswitch-apps"
    echo "--update --all"
    echo "--update --killswitch-apps"
    echo "--vpncheck"
    echo "--backup"
fi