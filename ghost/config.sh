#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _ghostBlogDomain

    echo -n "What should be the ${app^} subdomain? [ghost-blog]: "
    read _ghostBlogSubDomain

    if [ "$_ghostBlogDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_ghostBlogDomain'/g' .env
    fi

    if [ "$_ghostBlogSubDomain" ]; then
        sed -i 's/SUBDOMAIN=ghost-blog/SUBDOMAIN='$_ghostBlogSubDomain'/g' .env
    fi
fi