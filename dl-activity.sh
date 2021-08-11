#! /bin/bash

# Example crontab user entry: 
# * * * * * . $HOME/.profile $HOME/privacybox-docker/dl-activity.sh >/dev/null 2>&1

TIMESTAMP=$(date +"%Y%m%d-%H:%M")

DOCKERPATH=$(which docker)
COMPOSEPATH=$(which docker-compose)

BASEIP=$("${DOCKERPATH}" run --rm alpine /usr/bin/wget -qO - ifconfig.me)
VPNIP=$("${DOCKERPATH}" run --rm --network=container:expressvpn alpine /usr/bin/wget -qO - ifconfig.me)

WORKDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# # Additional debugging information
# echo "BASEIP = ${BASEIP}" >> ${WORKDIR}/vpnlog.txt
# echo "VPNIP = ${VPNIP}" >> ${WORKDIR}/vpnlog.txt

if [ "${VPNIP}" != "${BASEIP}" ]; then
    echo "${TIMESTAMP} VPN Up" >> ${WORKDIR}/vpnlog.txt

    echo "${TIMESTAMP} Keeping services running" >> ${WORKDIR}/vpnlog.txt
    cd ${WORKDIR}/transmission
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/nzbget
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/prowlarr
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/sonarr
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/radarr
    ${COMPOSEPATH} up -d
    # cd ${WORKDIR}/readarr
    # ${COMPOSEPATH} up -d
elif [ "${VPNIP}" == "${BASEIP}" ]; then
    echo "${TIMESTAMP} VPN Down" >> ${WORKDIR}/vpnlog.txt
    
    echo "${TIMESTAMP} Engaging killswitch" >> ${WORKDIR}/vpnlog.txt
    cd ${WORKDIR}/transmission
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/nzbget
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/prowlarr
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/sonarr
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/radarr
    ${COMPOSEPATH} down -v
    # cd ${WORKDIR}/readarr
    # ${COMPOSEPATH} down -v

    echo "${TIMESTAMP} Issuing VPN restart" >> ${WORKDIR}/vpnlog.txt
    cd ${WORKDIR}/expressvpn
    ${COMPOSEPATH} down -v
    ${COMPOSEPATH} up -d
else
    echo "Unable to determine VPN status" >> ${WORKDIR}/vpnlog.txt
fi

if [ "$1" == "--stop" ]; then
    cd ${WORKDIR}/transmission
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/nzbget
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/prowlarr
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/sonarr
    ${COMPOSEPATH} down -v
    cd ${WORKDIR}/radarr
    ${COMPOSEPATH} down -v
    # cd ${WORKDIR}/readarr
    # ${COMPOSEPATH} down -v

elif [ "$1" == "--start" ]; then
    cd ${WORKDIR}/expressvpn
    ${COMPOSEPATH} down -v
    ${COMPOSEPATH} up -d
    sleep 15

    cd ${WORKDIR}/transmission
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/nzbget
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/prowlarr
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/sonarr
    ${COMPOSEPATH} up -d
    cd ${WORKDIR}/radarr
    ${COMPOSEPATH} up -d
    # cd ${WORKDIR}/readarr
    # ${COMPOSEPATH} up -d
fi

