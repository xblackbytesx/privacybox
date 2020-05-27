#!/bin/bash

if [ "$1" == "--provision" ]; then
    source provision.sh
fi

source deploy.sh