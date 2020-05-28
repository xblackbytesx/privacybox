#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _nextcloudDomain

    echo -n "What should be the ${app^} subdomain? [nextcloud]: "
    read _nextcloudSubDomain

    if [ "$_nextcloudDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_nextcloudDomain'/g' .env
    fi

    if [ "$_nextcloudSubDomain" ]; then
        sed -i 's/SUBDOMAIN=nextcloud/SUBDOMAIN='$_nextcloudSubDomain'/g' .env
    fi
fi