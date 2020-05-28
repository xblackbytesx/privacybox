#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _piholeDomain

    echo -n "What should be the ${app^} subdomain? [pihole]: "
    read _piholeSubDomain

    if [ "$_piholeDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_piholeDomain'/g' .env
    fi

    if [ "$_piholeSubDomain" ]; then
        sed -i 's/SUBDOMAIN=pihole/SUBDOMAIN='$_piholeSubDomain'/g' .env
    fi
fi