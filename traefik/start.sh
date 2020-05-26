#!/bin/bash

echo -n "What should be the Traefik main domain? [$globalDomain]:"
read _traefikDomain

echo -n "What should be the Traefik subdomain? [traefik]"
read _traefikSubDomain

if [ "$_traefikDomain" ]; then
    sed -i 's/DOMAIN=privacy.box/DOMAIN=$_traefikDomain/g' .env
fi

if [ "$_traefikSubDomain" ]; then
    sed -i 's/SUBDOMAIN=traefik/SUBDOMAIN=$_traefikSubDomain/g' .env
fi