#!/bin/bash

if [ "$_initialConfig" = "true" ]; then
    echo "${app^} specific changes"
fi

if [ "$_customizeInstall" = "y" ]; then
    echo -n "What should be the ${app^} main domain? [$globalDomain]: "
    read _spotwebDomain

    echo -n "What should be the ${app^} subdomain? [spotweb]: "
    read _spotwebSubDomain

    echo -n "What should be the ${app^} 'root' database password? [global db root pass]: "
    read _spotwebDbRootPass

    echo -n "What should be the ${app^} 'spotweb' database password [db user pass]: "
    read _spotwebDbUserPass

    if [ "$_spotwebDomain" ]; then
        sed -i 's/DOMAIN='$globalDomain'/DOMAIN='$_spotwebDomain'/g' .env
    fi

    if [ "$_spotwebSubDomain" ]; then
        sed -i 's/SUBDOMAIN=spotweb/SUBDOMAIN='$_spotwebSubDomain'/g' .env
    fi

    if [ "$_spotwebDbRootPass" ]; then
        sed -i 's/ROOT_PASS=secret/ROOT_PASS='$_spotwebDbRootPass'/g' .env
    fi

    if [ "$_spotwebDbUserPass" ]; then
        sed -i 's/USER_PASS=secret/USER_PASS='$_spotwebDbUserPass'/g' .env
    fi
fi

# Tips to run after install:
# docker exec spotweb-app sed -i 's+= $nwsetting+= "https://$traefikSubDomain.$traefikDomain"+g' /var/www/spotweb/settings.php >/dev/null 2>&1
# docker exec spotweb-app su -l www-data -s /usr/bin/php /var/www/spotweb/retrieve.php >/dev/null 2>&1