#!/bin/bash

echo -n "What should be the Jackett main domain? [$globalDomain]:"
read _jackettDomain

echo -n "What should be the Jackett subdomain? [jackett]"
read _jackettSubDomain

if [ "$_jackettDomain" ]; then
    sed -i 's/DOMAIN=privacy.box/DOMAIN=$_jackettDomain/g' .env
fi

if [ "$_jackettSubDomain" ]; then
    sed -i 's/SUBDOMAIN=jackett/SUBDOMAIN=$_jackettSubDomain/g' .env
fi