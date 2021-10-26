#!/bin/bash

# Example crontab user entry: 
# * * * * * . $HOME/.profile $HOME/privacybox-docker/dl-activity.sh --vpncheck >/dev/null 2>&1

TIMESTAMP=$(date +"%Y%m%d-%H:%M")

# Defaults
DEPLOYED_APPS=( traefik portainer )
KILLSWITCH_APPS=( transmission nzbget spotweb )

# Read config
. ./privacybox.config

# Finding Docker binary
DOCKERPATH=$(which docker)
COMPOSEPATH=$(which docker-compose)

# Establishing privacybox dir location
WORKDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)


if [ "$1" == "--provision" ]; then
    source scripts/provision.sh


elif [ "$1" == "--start" ]; then
    if [ "$2" == "--all" ]; then
        for APP in "${DEPLOYED_APPS[@]}"
        do
        : 
            cd ${WORKDIR}/apps/$APP
            ${COMPOSEPATH} up -d
        done

        echo "${TIMESTAMP} All services started manually" >> ${WORKDIR}/logs/vpnlog.txt

    elif [ "$2" == "--killswitch" ]; then
        for APP in "${KILLSWITCH_APPS[@]}"
        do
        : 
            cd ${WORKDIR}/apps/$APP
            ${COMPOSEPATH} up -d
        done

        echo "${TIMESTAMP} Killswitch services started manually" >> ${WORKDIR}/logs/vpnlog.txt  
    fi

elif [ "$1" == "--stop" ]; then
    if [ "$2" == "--all" ]; then
        for APP in "${DEPLOYED_APPS[@]}"
        do
        : 
            cd ${WORKDIR}/apps/$APP
            ${COMPOSEPATH} down -v
        done

        echo "${TIMESTAMP} All services stopped manually" >> ${WORKDIR}/logs/vpnlog.txt
    
    elif [ "$2" == "--killswitch-apps" ]; then
        for APP in "${KILLSWITCH_APPS[@]}"
        do
        : 
            cd ${WORKDIR}/apps/$APP
            ${COMPOSEPATH} down -v
        done

        echo "${TIMESTAMP} Killswitch services stopped manually" >> ${WORKDIR}/logs/vpnlog.txt
    fi


elif [ "$1" == "--update" ]; then
    if [ "$2" == "--all" ]; then
        for APP in "${DEPLOYED_APPS[@]}"
        do
        : 
            cd ${WORKDIR}/apps/$APP
            ${COMPOSEPATH} pull && ${COMPOSEPATH} up -d --build
        done

        echo "${TIMESTAMP} Updated all services" >> ${WORKDIR}/logs/vpnlog.txt

    elif [ "$2" == "--killswitch-apps" ]; then
        for APP in "${KILLSWITCH_APPS[@]}"
        do
        : 
            cd ${WORKDIR}/apps/$APP
            ${COMPOSEPATH} pull && ${COMPOSEPATH} up -d --build
        done

        echo "${TIMESTAMP} Updated killswitch services" >> ${WORKDIR}/logs/vpnlog.txt
    fi

elif [ "$1" == "--vpncheck" ]; then
    BASEIP=$("${DOCKERPATH}" run --rm alpine /usr/bin/wget -qO - ifconfig.me)
    VPNIP=$("${DOCKERPATH}" run --rm --network=container:expressvpn alpine /usr/bin/wget -qO - ifconfig.me)

    # # Additional debugging information
    # echo "BASEIP = ${BASEIP}" >> ${WORKDIR}/logs/vpnlog.txt
    # echo "VPNIP = ${VPNIP}" >> ${WORKDIR}/logs/vpnlog.txt

    if [ "${VPNIP}" != "${BASEIP}" ]; then
        echo "${TIMESTAMP} VPN Up" >> ${WORKDIR}/logs/vpnlog.txt
        echo "${TIMESTAMP} Keeping services running" >> ${WORKDIR}/logs/vpnlog.txt

        for APP in "${KILLSWITCH_APPS[@]}"
        do
        : 
            cd ${WORKDIR}/apps/$APP
            ${COMPOSEPATH} up -d
        done

    elif [ "${VPNIP}" == "${BASEIP}" ]; then
        echo "${TIMESTAMP} VPN Down" >> ${WORKDIR}/logs/vpnlog.txt
        echo "${TIMESTAMP} Engaging killswitch" >> ${WORKDIR}/logs/vpnlog.txt

        for APP in "${KILLSWITCH_APPS[@]}"
        do
        : 
            cd ${WORKDIR}/apps/$APP
            ${COMPOSEPATH} down -v
        done

        echo "${TIMESTAMP} Issuing VPN restart" >> ${WORKDIR}/logs/vpnlog.txt
        cd ${WORKDIR}/apps/expressvpn
        ${COMPOSEPATH} down -v
        ${COMPOSEPATH} up -d
    else
        echo "Unable to determine VPN status" >> ${WORKDIR}/logs/vpnlog.txt
    fi


elif [ "$1" == "--backup" ]; then
    source scripts/backup-data.sh

else
    echo "Please append one of the following flags to this command:"
    echo "--provision"
    echo "--start --all"
    echo "--start --killswitch"
    echo "--stop --all"
    echo "--stop --killswitch"
    echo "--update --all"
    echo "--update --killswitch"
    echo "--vpncheck"
    echo "--backup"
fi