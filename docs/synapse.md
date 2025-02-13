# Synapse

## Initial setup
```
mkdir -p /media/storage/docker/synapse/{database,data,media,coturn}
```

To generate the required secrets run this command once
```
docker compose run --rm -v /media/storage/docker/synapse/data:/data synapse-app generate
```

Then bring down the related containers again and edit the homeserver.yml in the data folder manually
```
sudo vim /media/storage/docker/synapse/data/homeserver.yml
```

Keep all the generated keys and tokens but replace most of the config with the one found in `homeserver.example.yml`.

## DNS Settings
| Name                             | TTL | TYPE | VALUE                          |
|----------------------------------|-----|------|--------------------------------|
| synapse.privacy.box              |     | A    | <ipv4>                         |
| mas.synapse.privacy.box          |     | A    | <ipv4>                         |
| _matrix._tcp.synapse.privacy.box |     | SRV  | 10 5 8448 synapse.privacy.box. |

## Create users (including admin)
```
docker exec -it synapse-app register_new_matrix_user http://synapse-app:8008 -c /data/homeserver.yaml --user johndoe666
```