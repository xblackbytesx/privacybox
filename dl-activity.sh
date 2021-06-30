#! /bin/bash

# Example crontab user entry: 
# * * * * * ~/privacybox-docker/dl-activity.sh >/dev/null 2>&1

CURRTIME=$(date +%s)

BASEIP=$(docker run --rm -it alpine wget -qO - ifconfig.me)
VPNIP=$(docker run --rm -it --network=container:expressvpn alpine wget -qO - ifconfig.me)

WORKDIR=$(pwd)

if [ "${VPNIP}" != "${BASEIP}" ]; then
    echo "${CURRTIME} VPN Up" >> ${WORKDIR}/vpnlog.txt

    echo "${CURRTIME} Restarting services" >> ${WORKDIR}/vpnlog.txt
    cd ${WORKDIR}/transmission
    docker-compose up -d
    cd ${WORKDIR}/nzbget
    docker-compose up -d
    cd ${WORKDIR}/jackett
    docker-compose up -d
else
    echo "${CURRTIME} VPN Down" >> ${WORKDIR}/vpnlog.txt
    
    echo "${CURRTIME} Engaging killswitch" >> ${WORKDIR}/vpnlog.txt
    cd ${WORKDIR}/transmission
    docker-compose down -v
    cd ${WORKDIR}/nzbget
    docker-compose down -v
    cd ${WORKDIR}/jackett
    docker-compose down -v

    echo "${CURRTIME} Issuing restart" >> ${WORKDIR}/vpnlog.txt
    cd ${WORKDIR}/expressvpn
    docker-compose down -v
    docker-compose up -d
fi

if [ "$1" == "--stop" ]; then
    cd ${WORKDIR}/transmission
    docker-compose down -v
    cd ${WORKDIR}/nzbget
    docker-compose down -v
    cd ${WORKDIR}/jackett
    docker-compose down -v

elif [ "$1" == "--start" ]; then
    cd ${WORKDIR}/expressvpn
    docker-compose down -v
    docker-compose up -d
    sleep 15

    cd ${WORKDIR}/transmission
    docker-compose up -d
    cd ${WORKDIR}/nzbget
    docker-compose up -d
    cd ${WORKDIR}/jackett
    docker-compose up -d
fi

