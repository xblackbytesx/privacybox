#!/bin/bash

echo -n "What should be the Transmission main domain? [$globalDomain]:"
read _transmissionDomain

echo -n "What should be the Transmission subdomain? [transmission]"
read _transmissionSubDomain

echo -n "What should be the Transmission 'root' database password? [global db root pass]:"
read _transmissionDbRootPass

echo -n "What should be the Transmission 'transmission' database password [db user pass]"
read _transmissionDbUserPass

if [ "$_transmissionDomain" ]; then
    sed -i 's/DOMAIN=privacy.box/DOMAIN=$_transmissionDomain/g' .env
fi

if [ "$_transmissionSubDomain" ]; then
    sed -i 's/SUBDOMAIN=transmission/SUBDOMAIN=$_transmissionSubDomain/g' .env
fi

if [ "$_transmissionDbRootPass" ]; then
    sed -i 's/ROOT_PASS=secret/ROOT_PASS=$_transmissionDomain/g' .env
fi

if [ "$_transmissionDbUserPass" ]; then
    sed -i 's/USER_PASS=secret/USER_PASS=$_transmissionSubDomain/g' .env
fi    

if [ "$globalStorageRoot" ]; then
    sed -i 's/STORAGE_ROOT=\/media/storage/STORAGE_ROOT=$globalStorageRoot/g' .env
fi