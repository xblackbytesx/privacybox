#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _mastodonDomain

    echo -n "What should be the ${app^} subdomain? [mastodon]: "
    read _mastodonSubDomain

    if [ "$_mastodonDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_mastodonDomain'/g' .env
    fi

    if [ "$_mastodonSubDomain" ]; then
        sed -i 's/SUBDOMAIN=mastodon/SUBDOMAIN='$_mastodonSubDomain'/g' .env
    fi
fi