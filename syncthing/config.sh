#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _syncthingDomain

    echo -n "What should be the ${app^} subdomain? [syncthing]: "
    read _syncthingSubDomain

    echo -n "What email address should be used for LetsEncrypt Challenge? [$globalEmail]: "
    read _syncthingLeEmail

    if [ "$_syncthingDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_syncthingDomain'/g' .env
    fi

    if [ "$_syncthingSubDomain" ]; then
        sed -i 's/SUBDOMAIN=syncthing/SUBDOMAIN='$_syncthingSubDomain'/g' .env
    fi

    if [ "$_syncthingLeEmail" ]; then
        sed -i 's/EMAIL='$globalEmail'/EMAIL='$_syncthingLeEmail'/g' .env
    fi
fi