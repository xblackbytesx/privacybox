#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _nzbgetDomain

    echo -n "What should be the ${app^} subdomain? [nzbget]: "
    read _nzbgetSubDomain

    if [ "$_nzbgetDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_nzbgetDomain'/g' .env
    fi

    if [ "$_nzbgetSubDomain" ]; then
        sed -i 's/SUBDOMAIN=nzbget/SUBDOMAIN='$_nzbgetSubDomain'/g' .env
    fi
fi