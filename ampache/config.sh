#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _ampacheDomain

    echo -n "What should be the ${app^} subdomain? [music]: "
    read _ampacheSubDomain

    if [ "$_ampacheDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_ampacheDomain'/g' .env
    fi

    if [ "$_ampacheSubDomain" ]; then
        sed -i 's/SUBDOMAIN=music/SUBDOMAIN='$_ampacheSubDomain'/g' .env
    fi
fi