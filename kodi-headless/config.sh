#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _kodiDomain

    echo -n "What should be the ${app^} subdomain? [kodi]: "
    read _kodiSubDomain

    if [ "$_kodiDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_kodiDomain'/g' .env
    fi

    if [ "$_kodiSubDomain" ]; then
        sed -i 's/SUBDOMAIN=kodi/SUBDOMAIN='$_kodiSubDomain'/g' .env
    fi
fi