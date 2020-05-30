#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _wallabagDomain

    echo -n "What should be the ${app^} subdomain? [read]: "
    read _wallabagSubDomain

    echo -n "What should be the ${app^} 'root' database password? [global db root pass]: "
    read _wallabagDbRootPass

    echo -n "What should be the ${app^} 'wallabag' database password [db user pass]: "
    read _wallabagDbUserPass

    if [ "$_wallabagDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_wallabagDomain'/g' .env
    fi

    if [ "$_wallabagSubDomain" ]; then
        sed -i 's/SUBDOMAIN=read/SUBDOMAIN='$_wallabagSubDomain'/g' .env
    fi

    if [ "$_wallabagDbRootPass" ]; then
        sed -i 's/ROOT_PASS=secret/ROOT_PASS='$_wallabagDomain'/g' .env
    fi

    if [ "$_wallabagDbUserPass" ]; then
        sed -i 's/USER_PASS=secret/USER_PASS='$_wallabagSubDomain'/g' .env
    fi
fi