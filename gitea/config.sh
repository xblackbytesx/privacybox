#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _giteaDomain

    echo -n "What should be the ${app^} subdomain? [code]: "
    read _giteaSubDomain

    if [ "$_giteaDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_giteaDomain'/g' .env
    fi

    if [ "$_giteaSubDomain" ]; then
        sed -i 's/SUBDOMAIN=code/SUBDOMAIN='$_giteaSubDomain'/g' .env
    fi
fi