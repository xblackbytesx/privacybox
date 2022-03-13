# Matrix Synapse

## Before running:

#### Generate a configuration.
```
docker run -it --rm -v /media/storage/docker/matrix/synapse/data:/data -e SYNAPSE_SERVER_NAME=matrix.privacy.box -e SYNAPSE_REPORT_STATS=no -e UID="1000" -e GID="1000" -e TZ="Europe/Amsterdam" matrixdotorg/synapse:latest generate
```

#### Copy the generated configuration to your permanent volume
```
sudo cp -Rp /var/lib/docker/volumes/synapse-data/_data /media/storage/docker/synapse/data
```

NOTE: Default owner of the Synapse data folder is `991`

#### Edit the homeserver.yaml file

###### Use postgres as database:
Uncomment the postgres example in the config and set the apropriate values for your DB.
Also make sure to comment the old sqlite backend config.
```
database:
  name: psycopg2
  args:
    user: synapse
    password: secret
    database: synapse
    host: synapse-db
    cp_min: 5
    cp_max: 10
```

###### Allow user registartion
Find and uncomment the line `allow_registration` and set it's value to true.
```
allow_registration: true
```