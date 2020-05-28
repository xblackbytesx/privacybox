#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _nodeRedDomain

    echo -n "What should be the ${app^} subdomain? [nodered]: "
    read _nodeRedSubDomain

    if [ "$_nodeRedDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_nodeRedDomain'/g' .env
    fi

    if [ "$_nodeRedSubDomain" ]; then
        sed -i 's/SUBDOMAIN=nodered/SUBDOMAIN='$_nodeRedSubDomain'/g' .env
    fi
fi