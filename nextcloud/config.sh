#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _nextcloudDomain

    echo -n "What should be the ${app^} subdomain? [www]: "
    read _nextcloudSubDomain

    echo -n "What should be the ${app^} 'root' database password? [global db root pass]: "
    read _nextcloudDbRootPass

    echo -n "What should be the ${app^} 'nextcloud' database password [db user pass]: "
    read _nextcloudDbUserPass

    if [ "$_nextcloudDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_nextcloudDomain'/g' .env
    fi

    if [ "$_nextcloudSubDomain" ]; then
        sed -i 's/SUBDOMAIN=www/SUBDOMAIN='$_nextcloudSubDomain'/g' .env
    fi

    if [ "$_nextcloudDbRootPass" ]; then
        sed -i 's/ROOT_PASS=secret/ROOT_PASS='$_nextcloudDomain'/g' .env
    fi

    if [ "$_nextcloudDbUserPass" ]; then
        sed -i 's/USER_PASS=secret/USER_PASS='$_nextcloudSubDomain'/g' .env
    fi
fi