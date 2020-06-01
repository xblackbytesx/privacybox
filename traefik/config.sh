#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "Checking if neccesary .key file exists"
    count=`ls -1 data/*.key 2>/dev/null | wc -l`
    if [ $count = 0 ]; then 
        echo "Please ensure a valid private/API key is present in '${pwd}/data for your DNS provider"
        exit 1
    fi 

    echo -n "What is your DNS providers username: [someone] "
    read _traefikDnsAccountUser
    if [ "$_traefikDnsAccountUser" ]; then
        sed -i 's/ACCOUNT_NAME=someone/ACCOUNT_NAME='$_traefikDnsAccountUser'/g' .env
    fi

    sed -i 's/EMAIL=john.doe@privacy.box/EMAIL='$globalEmail'/g' .env

    echo "${app^} specific changes"

    # Make sure the config is unmodified before replacing
    git checkout data/traefik.yml

    sed -i 's/email: john.doe@privacy.box/email: '$globalEmail'/g' ./data/traefik.yml
    sed -i 's/email: john.doe@privacy.box/email: '$globalEmail'/g' ./data/traefik.yml
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _traefikDomain

    echo -n "What should be the ${app^} subdomain? [traefik]: "
    read _traefikSubDomain

    echo -n "What email address should be used for LetsEncrypt Challenge? [$globalEmail]: "
    read _traefikLeEmail

    if [ "$_traefikDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_traefikDomain'/g' .env
    fi

    if [ "$_traefikSubDomain" ]; then
        sed -i 's/SUBDOMAIN=traefik/SUBDOMAIN='$_traefikSubDomain'/g' .env
    fi

    if [ "$_traefikLeEmail" ]; then
        sed -i 's/EMAIL='$globalEmail'/EMAIL='$_traefikLeEmail'/g' .env

        git checkout data/traefik.yml

        sed -i 's/email: '$globalEmail'/email: '$_traefikLeEmail'/g' ./data/traefik.yml
        sed -i 's/email: '$globalEmail'/email: '$_traefikLeEmail'/g' ./data/traefik.yml
    fi
fi