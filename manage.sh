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

# Finding Docker binary
DOCKERPATH=$(which docker)
COMPOSEPATH=$(which docker-compose)

# Establishing privacybox dir locations
PRIVACYBOX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
DOCKER_DATA_DIR=$DOCKER_ROOT
BACKUP_DIR=$BACKUP_ROOT

ACTION_FLAG=$1
ACTION_SCOPE=$2
ACTION_FLAG_CLEAN="${1:2}"
ACTION_SCOPE_CLEAN="${2:2}"


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


container_state () {
    local action=$1
    local app_name=$2
  
    if [[ -d "${PRIVACYBOX_DIR}/apps/$app_name" ]]
    then
        cd ${PRIVACYBOX_DIR}/apps/$app_name
    else
        echo "'$app_name' Is not a valid service."
        exit 1
    fi

    case "$action" in
        "--start")
            local action_msg="Started"
            ${COMPOSEPATH} up -d
            ;;
        "--stop")
            local action_msg="Stopped"
            ${COMPOSEPATH} down -v
            ;;
        "--restart")
            local action_msg="Restart"
            ${COMPOSEPATH} down -v
            ${COMPOSEPATH} up -d
            ;;
        "--update")
            local action_msg="Updated"
            ${COMPOSEPATH} pull && ${COMPOSEPATH} up -d --build
            ;;
        *)
            echo "Given action '$action' does not exist"
            exit 1
    esac

    echo "${TIMESTAMP_MINUTE} $app_name service $action_msg manually" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
}


###################
## Command flags ##
###################
case "$ACTION_FLAG" in
    "--provision")
        source scripts/provision.sh
        ;;

    "--getcompose")
        echo "Installing latest docker-compose"
        sudo mv ${COMPOSEPATH} ${COMPOSEPATH}BAK${TIMESTAMP_MINUTE}
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o ${COMPOSEPATH}
        sudo chmod +x ${COMPOSEPATH}
        echo "Succesfully installed $(${COMPOSEPATH} --version)"
        ;;

    "--free-dsm-ports")
        source scripts/free-dsm-ports.sh
        ;;

    "--start"|"--stop"|"--update"|"--restart")
        case "$ACTION_SCOPE" in
            "--all")
                if [ -z ${DEPLOYED_APPS} ]; then 
                    echo "No deployed apps are configured. Please check your privacybox.config file.";
                else
                    for APP in "${DEPLOYED_APPS[@]}"
                    do
                    : 
                        container_state $ACTION_FLAG $APP
                    done
                fi
                ;;

            "--killswitch-apps")
                if [ -z ${KILLSWITCH_APPS} ]; then 
                    echo "No killswitch apps are configured. Please check your privacybox.config file.";
                else
                    for APP in "${KILLSWITCH_APPS[@]}"
                    do
                    : 
                        container_state $ACTION_FLAG $APP
                    done
                fi
                ;;

            "--ghost"|"--wordpress")

                if [ "$1" == "--start" ]; then
                    for DEPLOYMENT in "./apps/$APP_NAME/deployments/"*
                    do
                    :
                        cd ${PRIVACYBOX_DIR}/$DEPLOYMENT
                        ${COMPOSEPATH} up -d
                        echo "Started $APP_NAME DEPLOYMENT: $DEPLOYMENT" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
                    done
                
                elif [ "$1" == "--stop" ]; then
                    for DEPLOYMENT in "./apps/$APP_NAME/deployments/"*
                    do
                    :
                        cd ${PRIVACYBOX_DIR}/$DEPLOYMENT
                        ${COMPOSEPATH} down -v
                        echo "Stopped $APP_NAME deployment: $DEPLOYMENT" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
                    done

                elif [ "$1" == "--restart" ]; then
                    for DEPLOYMENT in "./apps/$APP_NAME/deployments/"*
                    do
                    :
                        cd ${PRIVACYBOX_DIR}/$DEPLOYMENT
                        ${COMPOSEPATH} down -v
                        ${COMPOSEPATH} up -d
                        echo "Restarted $APP_NAME deployment: $DEPLOYMENT" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
                    done

                elif [ "$1" == "--update" ]; then
                    for DEPLOYMENT in "./apps/$APP_NAME/deployments/"*
                    do
                    :
                        cd ${PRIVACYBOX_DIR}/$DEPLOYMENT
                        ${COMPOSEPATH} pull && ${COMPOSEPATH} up -d --build
                        echo "Updated $APP_NAME deployment: $DEPLOYMENT" >> ${PRIVACYBOX_DIR}/logs/privacybox.log
                    done
                fi
                ;;
            *)  
                container_state $ACTION_FLAG $ACTION_SCOPE_CLEAN
                exit 1
        esac
        ;;

    "--vpncheck")
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
        ;;

    "--backup")
        mkdir -p $BACKUP_DIR
        sudo tar --exclude=${DOCKER_DATA_DIR}/photoprism/data/albums  --exclude=${DOCKER_DATA_DIR}/photoprism/data/cache  --exclude=${DOCKER_DATA_DIR}/photoprism/data/serial --exclude=${DOCKER_DATA_DIR}/pigallery/temp --exclude=${DOCKER_DATA_DIR}/photoprism/data/sidecar --exclude=${DOCKER_DATA_DIR}/jellyfin --exclude=${DOCKER_DATA_DIR}/jellyfinBAK -zcvpf $BACKUP_DIR/$TIMESTAMP_HOUR-$SERVER_NAME.tar.gz $PRIVACYBOX_DIR $DOCKER_DATA_DIR
        ;;

    *)
        echo "Please append one of the following flags to this command:"
        echo "--provision"
        echo "--getcompose"
        echo "--free-dsm-ports"
        echo "--start --all"
        echo "--start --killswitch-apps"
        echo "--start --ghost"
        echo "--start --wordpress"
        echo "--stop --all"
        echo "--stop --killswitch-apps"
        echo "--stop --ghost"
        echo "--stop --wordpress"
        echo "--restart --all"
        echo "--restart --killswitch-apps"
        echo "--restart --ghost"
        echo "--restart --wordpress"
        echo "--update --all"
        echo "--update --killswitch-apps"
        echo "--update --ghost"
        echo "--update --wordpress"
        echo "--vpncheck"
        echo "--backup"
        exit 1
esac
