#!/bin/bash

echo -n "What should be the Sonarr main domain? [$globalDomain]: "
read _sonarrDomain

echo -n "What should be the Sonarr subdomain? [sonarr]: "
read _sonarrSubDomain

if [ "$_sonarrDomain" ]; then
    sed -i 's/DOMAIN=privacy.box/DOMAIN=$_sonarrDomain/g' .env
fi

if [ "$_sonarrSubDomain" ]; then
    sed -i 's/SUBDOMAIN=sonarr/SUBDOMAIN=$_sonarrSubDomain/g' .env
fi