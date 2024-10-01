#!/bin/bash

   set -e
   set -u

   function create_user_and_database() {
       local database=$1
       local user=$2
       local password=$3
       echo "  Creating user and database '$database'"
       psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
           CREATE USER $user WITH PASSWORD '$password';
           CREATE DATABASE $database;
           GRANT ALL PRIVILEGES ON DATABASE $database TO $user;
   EOSQL
   }

   if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
       echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
       for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
           IFS=':' read -ra DB_INFO <<< "$db"
           create_user_and_database ${DB_INFO[0]} ${DB_INFO[1]} ${DB_INFO[2]}
       done
       echo "Multiple databases created"
   fi