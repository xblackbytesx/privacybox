# Synapse

To generate the required secrets run this command once
```
docker compose run --rm -v /media/storage/docker/synapse/data:/data synapse-app generate
```

Then bring down the related containers again and edit the homeserver.yml in the data folder manually
```
sudo vim /media/storage/docker/synapse/data/homeserver.yml
```

Keep all the generated keys and tokens but replace most of the config with the one found in `homeserver.example.yml`.

