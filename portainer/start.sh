#!/bin/bash

echo -n "What should be the Portainer main domain? [$globalDomain]: "
read _portainerDomain

echo -n "What should be the Portainer subdomain? [portainer]: "
read _portainerSubDomain

if [ "$_portainerDomain" ]; then
    sed -i 's/DOMAIN=privacy.box/DOMAIN=$_portainerDomain/g' .env
fi

if [ "$_portainerSubDomain" ]; then
    sed -i 's/SUBDOMAIN=portainer/SUBDOMAIN=$_portainerSubDomain/g' .env
fi