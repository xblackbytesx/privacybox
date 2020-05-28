#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _transmissionDomain

    echo -n "What should be the ${app^} subdomain? [transmission]: "
    read _transmissionSubDomain

    if [ "$_transmissionDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_transmissionDomain'/g' .env
    fi

    if [ "$_transmissionSubDomain" ]; then
        sed -i 's/SUBDOMAIN=transmission/SUBDOMAIN='$_transmissionSubDomain'/g' .env
    fi
fi