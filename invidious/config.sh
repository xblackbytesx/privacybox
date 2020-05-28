#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _invidiousDomain

    echo -n "What should be the ${app^} subdomain? [videos]: "
    read _invidiousSubDomain

    if [ "$_invidiousDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_invidiousDomain'/g' .env
    fi

    if [ "$_invidiousSubDomain" ]; then
        sed -i 's/SUBDOMAIN=videos/SUBDOMAIN='$_invidiousSubDomain'/g' .env
    fi
fi