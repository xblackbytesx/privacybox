#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _wallabagDomain

    echo -n "What should be the ${app^} subdomain? [read]: "
    read _wallabagSubDomain

    if [ "$_wallabagDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_wallabagDomain'/g' .env
    fi

    if [ "$_wallabagSubDomain" ]; then
        sed -i 's/SUBDOMAIN=read/SUBDOMAIN='$_wallabagSubDomain'/g' .env
    fi
fi