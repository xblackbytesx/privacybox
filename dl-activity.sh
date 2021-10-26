#! /bin/bash

# Example crontab user entry: 
# * * * * * . $HOME/.profile $HOME/privacybox-docker/dl-activity.sh --vpncheck >/dev/null 2>&1

TIMESTAMP=$(date +"%Y%m%d-%H:%M")

DOCKERPATH=$(which docker)
COMPOSEPATH=$(which docker-compose)

WORKDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

if [ "$1" == "--vpncheck" ]; then
    BASEIP=$("${DOCKERPATH}" run --rm alpine /usr/bin/wget -qO - ifconfig.me)
    VPNIP=$("${DOCKERPATH}" run --rm --network=container:expressvpn alpine /usr/bin/wget -qO - ifconfig.me)

    # # Additional debugging information
    # echo "BASEIP = ${BASEIP}" >> ${WORKDIR}/logs/vpnlog.txt
    # echo "VPNIP = ${VPNIP}" >> ${WORKDIR}/logs/vpnlog.txt

    if [ "${VPNIP}" != "${BASEIP}" ]; then
        echo "${TIMESTAMP} VPN Up" >> ${WORKDIR}/logs/vpnlog.txt

        echo "${TIMESTAMP} Keeping services running" >> ${WORKDIR}/logs/vpnlog.txt
        cd ${WORKDIR}/apps/transmission
        ${COMPOSEPATH} up -d
        cd ${WORKDIR}/apps/nzbget
        ${COMPOSEPATH} up -d
        cd ${WORKDIR}/apps/spotweb
        ${COMPOSEPATH} up -d
        cd ${WORKDIR}/apps/prowlarr
        ${COMPOSEPATH} up -d
        cd ${WORKDIR}/apps/sonarr
        ${COMPOSEPATH} up -d
        cd ${WORKDIR}/apps/radarr
        ${COMPOSEPATH} up -d
        cd ${WORKDIR}/apps/readarr
        ${COMPOSEPATH} up -d
        cd ${WORKDIR}/apps/lidarr
        ${COMPOSEPATH} up -d
    elif [ "${VPNIP}" == "${BASEIP}" ]; then
        echo "${TIMESTAMP} VPN Down" >> ${WORKDIR}/logs/vpnlog.txt
        
        echo "${TIMESTAMP} Engaging killswitch" >> ${WORKDIR}/logs/vpnlog.txt
        cd ${WORKDIR}/apps/transmission
        ${COMPOSEPATH} down -v
        cd ${WORKDIR}/apps/nzbget
        ${COMPOSEPATH} down -v
        cd ${WORKDIR}/apps/spotweb
        ${COMPOSEPATH} down -v
        cd ${WORKDIR}/apps/prowlarr
        ${COMPOSEPATH} down -v
        cd ${WORKDIR}/apps/sonarr
        ${COMPOSEPATH} down -v
        cd ${WORKDIR}/apps/radarr
        ${COMPOSEPATH} down -v
        cd ${WORKDIR}/apps/readarr
        ${COMPOSEPATH} down -v
        cd ${WORKDIR}/apps/lidarr
        ${COMPOSEPATH} down -v

        echo "${TIMESTAMP} Issuing VPN restart" >> ${WORKDIR}/logs/vpnlog.txt
        cd ${WORKDIR}/apps/expressvpn
        ${COMPOSEPATH} down -v
        ${COMPOSEPATH} up -d
    else
        echo "Unable to determine VPN status" >> ${WORKDIR}/logs/vpnlog.txt
    fi

elif [ "$1" == "--stop" ]; then
    cd ${WORKDIR}/apps/transmission
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/apps/nzbget
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/apps/spotweb
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/apps/prowlarr
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/apps/sonarr
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/apps/radarr
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/apps/readarr
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/apps/lidarr
    ${COMPOSEPATH} down -v

    echo "${TIMESTAMP} Services stopped manually" >> ${WORKDIR}/logs/vpnlog.txt

elif [ "$1" == "--start" ]; then
    cd ${WORKDIR}/apps/expressvpn
    ${COMPOSEPATH} down -v
    ${COMPOSEPATH} up -d
    sleep 15

    cd ${WORKDIR}/apps/transmission
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/apps/nzbget
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/apps/spotweb
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/apps/prowlarr
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/apps/sonarr
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/apps/radarr
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/apps/readarr
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/apps/lidarr
    ${COMPOSEPATH} up -d

    echo "${TIMESTAMP} Services resumed manually" >> ${WORKDIR}/logs/vpnlog.txt
fi

