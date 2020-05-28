#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _portainerDomain

    echo -n "What should be the ${app^} subdomain? [portainer]: "
    read _portainerSubDomain

    if [ "$_portainerDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_portainerDomain'/g' .env
    fi

    if [ "$_portainerSubDomain" ]; then
        sed -i 's/SUBDOMAIN=portainer/SUBDOMAIN='$_portainerSubDomain'/g' .env
    fi
fi