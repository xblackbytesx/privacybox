#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _sonarrDomain

    echo -n "What should be the ${app^} subdomain? [sonarr]: "
    read _sonarrSubDomain

    if [ "$_sonarrDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_sonarrDomain'/g' .env
    fi

    if [ "$_sonarrSubDomain" ]; then
        sed -i 's/SUBDOMAIN=sonarr/SUBDOMAIN='$_sonarrSubDomain'/g' .env
    fi
fi