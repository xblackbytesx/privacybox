#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _meetDomain

    echo -n "What should be the ${app^} subdomain? [meet]: "
    read _meetSubDomain

    if [ "$_meetDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_meetDomain'/g' .env
    fi

    if [ "$_meetSubDomain" ]; then
        sed -i 's/SUBDOMAIN=meet/SUBDOMAIN='$_meetSubDomain'/g' .env
    fi
fi