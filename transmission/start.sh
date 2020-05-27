#!/bin/bash

echo -n "What should be the Transmission main domain? [$globalDomain]: "
read _transmissionDomain

echo -n "What should be the Transmission subdomain? [transmission]: "
read _transmissionSubDomain

if [ "$_transmissionDomain" ]; then
    sed -i 's/DOMAIN=privacy.box/DOMAIN=$_transmissionDomain/g' .env
fi

if [ "$_transmissionSubDomain" ]; then
    sed -i 's/SUBDOMAIN=transmission/SUBDOMAIN=$_transmissionSubDomain/g' .env
fi