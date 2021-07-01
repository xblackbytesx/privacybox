#! /bin/bash

# Example crontab user entry: 
# * * * * * /bin/bash /home/john/privacybox-docker/dl-activity.sh >/dev/null 2>&1

TIMESTAMP=$(date +"%Y%m%d-%H:%M")

BASEIP=$(/usr/bin/docker run --rm -it alpine wget -qO - ifconfig.me)
VPNIP=$(/usr/bin/docker run --rm -it --network=container:expressvpn alpine wget -qO - ifconfig.me)

WORKDIR="${HOME}/privacybox-docker"

if [ "${VPNIP}" != "${BASEIP}" ]; then
    echo "${TIMESTAMP} VPN Up" >> ${WORKDIR}/vpnlog.txt

    echo "${TIMESTAMP} Restarting services" >> ${WORKDIR}/vpnlog.txt
    cd ${WORKDIR}/transmission
    /usr/local/bin/docker-compose up -d
    cd ${WORKDIR}/nzbget
    /usr/local/bin/docker-compose up -d
    cd ${WORKDIR}/prowlarr
    /usr/local/bin/docker-compose up -d
elif [ "${VPNIP}" == "${BASEIP}" ]; then
    echo "${TIMESTAMP} VPN Down" >> ${WORKDIR}/vpnlog.txt
    
    echo "${TIMESTAMP} Engaging killswitch" >> ${WORKDIR}/vpnlog.txt
    cd ${WORKDIR}/transmission
    /usr/local/bin/docker-compose down -v
    cd ${WORKDIR}/nzbget
    /usr/local/bin/docker-compose down -v
    cd ${WORKDIR}/prowlarr
    /usr/local/bin/docker-compose down -v

    echo "${TIMESTAMP} Issuing restart" >> ${WORKDIR}/vpnlog.txt
    cd ${WORKDIR}/expressvpn
    /usr/local/bin/docker-compose down -v
    /usr/local/bin/docker-compose up -d
else
    echo "Unable to determine VPN status" >> ${WORKDIR}/vpnlog.txt
fi

if [ "$1" == "--stop" ]; then
    cd ${WORKDIR}/transmission
    /usr/local/bin/docker-compose down -v
    cd ${WORKDIR}/nzbget
    /usr/local/bin/docker-compose down -v
    cd ${WORKDIR}/prowlarr
    /usr/local/bin/docker-compose down -v

elif [ "$1" == "--start" ]; then
    cd ${WORKDIR}/expressvpn
    /usr/local/bin/docker-compose down -v
    /usr/local/bin/docker-compose up -d
    sleep 15

    cd ${WORKDIR}/transmission
    /usr/local/bin/docker-compose up -d
    cd ${WORKDIR}/nzbget
    /usr/local/bin/docker-compose up -d
    cd ${WORKDIR}/prowlarr
    /usr/local/bin/docker-compose up -d
fi

