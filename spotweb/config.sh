#!/bin/bash

echo -n "What should be the Spotweb main domain? [$globalDomain]: "
read _spotwebDomain

echo -n "What should be the Spotweb subdomain? [spotweb]: "
read _spotwebSubDomain

echo -n "What should be the Spotweb 'root' database password? [global db root pass]: "
read _spotwebDbRootPass

echo -n "What should be the Spotweb 'spotweb' database password [db user pass]: "
read _spotwebDbUserPass

if [ "$_spotwebDomain" ]; then
    sed -i 's/DOMAIN=privacy.box/DOMAIN=$_spotwebDomain/g' .env
fi

if [ "$_spotwebSubDomain" ]; then
    sed -i 's/SUBDOMAIN=spotweb/SUBDOMAIN=$_spotwebSubDomain/g' .env
fi

if [ "$_spotwebDbRootPass" ]; then
    sed -i 's/ROOT_PASS=secret/ROOT_PASS=$_spotwebDomain/g' .env
fi

if [ "$_spotwebDbUserPass" ]; then
    sed -i 's/USER_PASS=secret/USER_PASS=$_spotwebSubDomain/g' .env
fi

# Tips to run after install:
# docker exec spotweb-app sed -i 's+= $nwsetting+= "https://$traefikSubDomain.$traefikDomain"+g' /var/www/spotweb/settings.php >/dev/null 2>&1
# docker exec spotweb-app su -l www-data -s /usr/bin/php /var/www/spotweb/retrieve.php >/dev/null 2>&1