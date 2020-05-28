#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _jackettDomain

    echo -n "What should be the ${app^} subdomain? [jackett]: "
    read _jackettSubDomain

    if [ "$_jackettDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_jackettDomain'/g' .env
    fi

    if [ "$_jackettSubDomain" ]; then
        sed -i 's/SUBDOMAIN=jackett/SUBDOMAIN='$_jackettSubDomain'/g' .env
    fi
fi