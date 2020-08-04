#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _netdataDomain

    echo -n "What should be the ${app^} subdomain? [netdata]: "
    read _netdataSubDomain

    echo -n "What email address should be used for LetsEncrypt Challenge? [$globalEmail]: "
    read _netdataLeEmail

    if [ "$_netdataDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_netdataDomain'/g' .env
    fi

    if [ "$_netdataSubDomain" ]; then
        sed -i 's/SUBDOMAIN=netdata/SUBDOMAIN='$_netdataSubDomain'/g' .env
    fi

    if [ "$_netdataLeEmail" ]; then
        sed -i 's/EMAIL='$globalEmail'/EMAIL='$_netdataLeEmail'/g' .env
    fi
fi