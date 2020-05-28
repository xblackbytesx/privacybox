#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _hugoSite1Domain

    echo -n "What should be the ${app^} subdomain? [hugo-site]: "
    read _hugoSite1SubDomain

    if [ "$_hugoSite1Domain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_hugoSite1Domain'/g' .env
    fi

    if [ "$_hugoSite1SubDomain" ]; then
        sed -i 's/SUBDOMAIN=hugo-site/SUBDOMAIN='$_hugoSite1SubDomain'/g' .env
    fi
fi