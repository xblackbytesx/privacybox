#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _wordpressDomain

    echo -n "What should be the ${app^} subdomain? [wordpress]: "
    read _wordpressSubDomain

    if [ "$_wordpressDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_wordpressDomain'/g' .env
    fi

    if [ "$_wordpressSubDomain" ]; then
        sed -i 's/SUBDOMAIN=wordpress/SUBDOMAIN='$_wordpressSubDomain'/g' .env
    fi
fi