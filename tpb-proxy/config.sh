#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
    rm -rf app
    git clone https://github.com/piratebayproxy/UnblockedPiratebayClean.git app
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _tpbDomain

    echo -n "What should be the ${app^} subdomain? [tpb]: "
    read _tpbSubDomain

    if [ "$_tpbDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_tpbDomain'/g' .env
    fi

    if [ "$_tpbSubDomain" ]; then
        sed -i 's/SUBDOMAIN=tpb/SUBDOMAIN='$_tpbSubDomain'/g' .env
    fi
fi