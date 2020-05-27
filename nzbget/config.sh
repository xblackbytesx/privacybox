#!/bin/bash

echo -n "What should be the NZBget main domain? [$globalDomain]: "
read _nzbgetDomain

echo -n "What should be the NZBget subdomain? [nzbget]: "
read _nzbgetSubDomain

if [ "$_nzbgetDomain" ]; then
    sed -i 's/DOMAIN=privacy.box/DOMAIN=$_nzbgetDomain/g' .env
fi

if [ "$_nzbgetSubDomain" ]; then
    sed -i 's/SUBDOMAIN=nzbget/SUBDOMAIN=$_nzbgetSubDomain/g' .env
fi