#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _radarrDomain

    echo -n "What should be the ${app^} subdomain? [radarr]: "
    read _radarrSubDomain

    if [ "$_radarrDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_radarrDomain'/g' .env
    fi

    if [ "$_radarrSubDomain" ]; then
        sed -i 's/SUBDOMAIN=radarr/SUBDOMAIN='$_radarrSubDomain'/g' .env
    fi
fi