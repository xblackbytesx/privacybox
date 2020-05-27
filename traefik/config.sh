#!/bin/bash

echo -n "What should be the Traefik main domain? [$globalDomain]: "
read _traefikDomain

echo -n "What should be the Traefik subdomain? [traefik]: "
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
fi