#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _wordpressDomain

    echo -n "What should be the ${app^} subdomain? [wordpress]: "
    read _wordpressSubDomain

    echo -n "What should be the ${app^} 'root' database password? [global db root pass]: "
    read _wordpressDbRootPass

    echo -n "What should be the ${app^} 'wordpress' database password [db user pass]: "
    read _wordpressDbUserPass

    if [ "$_wordpressDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_wordpressDomain'/g' .env
    fi

    if [ "$_wordpressSubDomain" ]; then
        sed -i 's/SUBDOMAIN=wordpress/SUBDOMAIN='$_wordpressSubDomain'/g' .env
    fi

    if [ "$_wordpressDbRootPass" ]; then
        sed -i 's/ROOT_PASS=secret/ROOT_PASS='$_wordpressDbRootPass'/g' .env
    fi

    if [ "$_wordpressDbUserPass" ]; then
        sed -i 's/USER_PASS=secret/USER_PASS='$_wordpressDbUserPass'/g' .env
    fi
fi