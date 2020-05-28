#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _matomoDomain

    echo -n "What should be the ${app^} subdomain? [stats]: "
    read _matomoSubDomain

    if [ "$_matomoDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_matomoDomain'/g' .env
    fi

    if [ "$_matomoSubDomain" ]; then
        sed -i 's/SUBDOMAIN=stats/SUBDOMAIN='$_matomoSubDomain'/g' .env
    fi
fi