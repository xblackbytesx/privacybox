#! /bin/bash

if [ "$1" == "--stop" ]; then
    cd transmission
    docker-compose down -v
    cd ../nzbget
    docker-compose down -v
    cd ../jackett
    docker-compose down -v

elif [ "$1" == "--start" ]; then
    cd expressvpn
    docker-compose down -v
    docker-compose up -d
    sleep 15
    cd ../transmission
    docker-compose up -d
    cd ../nzbget
    docker-compose up -d
    cd ../jackett
    docker-compose up -d
fi

