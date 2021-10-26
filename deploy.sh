#!/bin/bash

echo "#######################"
echo "#### ~DOCKER TIME~ ####"
echo "#######################"

echo -n "What should be your main domain? [privacy.box]: "
read globalDomain

echo -n "What should be your main email address? [john.doe@privacy.box]: "
read globalEmail

echo -n "What should be the global database 'root' password? [secret]: "
read globalDbRootPass

echo -n "What should be the global database 'user' password? [secret]: "
read globalDbUserPass

echo -n "What should be the data storage root folder? [/media/storage]: "
read globalStorageRoot

if [ -z "$globalDomain" ]; then
    globalDomain='privacy.box'
fi

if [ -z "$globalEmail" ]; then
    globalEmail='john.doe@privacy.box'
fi

if [ -z "$globalStorageRoot" ]; then
    globalStorageRoot='/media/storage'
fi


# TODO: Make this list configurable
declare -a appsToInstall=("traefik" "portainer" "sonarr" "radarr" "jackett" "spotweb" "transmission" "nzbget")

echo "Creating the shared proxy network"
docker network create proxy

for app in ${appsToInstall[@]}; do
    echo "Setting up the ${app^} container"
    cd ./$app

    rm .env
    git checkout .env.example
    cp .env.example .env

    sed -i 's/DOMAIN=privacy.box/DOMAIN='$globalDomain'/g' .env

    if [ "$globalDbRootPass" ]; then
        sed -i 's/ROOT_PASS=secret/ROOT_PASS='$globalDbRootPass'/g' .env
    fi

    if [ "$globalDbUserPass" ]; then
        sed -i 's/USER_PASS=secret/USER_PASS='$globalDbUserPass'/g' .env
    fi

    if [ "$globalStorageRoot" ]; then
        sed -i 's/DOCKER_ROOT=\/media\/storage/DOCKER_ROOT='$globalStorageRoot'/g' .env
    fi

    _initialConfig='true'
    source config.sh
    _initialConfig='false'

    echo "Proposed ${app^} configuration:"
    echo "----------------"
    echo ""
    cat .env
    echo ""
    echo "----------------"

    echo -n "Customize ${app^} install? [n]: "
    read _customizeInstall
    
    source config.sh;

    echo "Effective ${app^} configuration:"
    echo "----------------"
    echo ""
    cat .env
    echo ""
    echo "----------------"

    echo "Starting ${app^} container(s)"
    docker-compose up -d

    echo "POW!! Done!... NEXT!"

    cd ../
done