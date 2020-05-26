#!/bin/bash

echo -n "What should be the Radarr main domain? [$globalDomain]:"
read _radarrDomain

echo -n "What should be the Radarr subdomain? [radarr]"
read _radarrSubDomain

if [ "$_radarrDomain" ]; then
    sed -i 's/DOMAIN=privacy.box/DOMAIN=$_radarrDomain/g' .env
fi

if [ "$_radarrSubDomain" ]; then
    sed -i 's/SUBDOMAIN=radarr/SUBDOMAIN=$_radarrSubDomain/g' .env
fi