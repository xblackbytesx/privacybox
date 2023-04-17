#!/bin/bash

# Full credits to the following source!:
# https://gist.github.com/hjbotha/f64ef2e0cd1e8ba5ec526dcd6e937dd7#gistcomment-2869917

# Save this script in one of your shares and schedule it to run as root at boot:
# Control Panel -> Task Scheduler

# DSM upgrades will reset these changes, which is why we schedule them to happen automatically
# Set the variables below if you want to customise the ports which DSM will listen on instead
# NOTE: These ports are used for some services, e.g. Photo Station

HTTP_PORT=80
HTTP_PATCH_PORT=1080

HTTPS_PORT=443
HTTPS_PATCH_PORT=1443

sed -i "s/^\( *listen .*\)$HTTP_PATCH_PORT/\1$HTTP_PORT/" /usr/syno/share/nginx/*.mustache
sed -i "s/^\( *listen .*\)$HTTP_PORT/\1$HTTP_PATCH_PORT/" /usr/syno/share/nginx/*.mustache

sed -i "s/^\( *listen .*\)$HTTPS_PATCH_PORT/\1$HTTPS_PORT/" /usr/syno/share/nginx/*.mustache
sed -i "s/^\( *listen .*\)$HTTPS_PORT/\1$HTTPS_PATCH_PORT/" /usr/syno/share/nginx/*.mustache

echo "Done!"
echo "Don't forget to add this script to your boot scripts using the scheduler: Control Panel -> Task Schedule"