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

## List registration_tokens
```
docker exec -it synapse-db psql -U synapse -d synapse -c "SELECT token FROM registration_tokens;"
```

OR through the API

```
curl -X GET \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN" \
  "https://matrix.privacy.box/_synapse/admin/v1/registration_tokens"
```

## Generate registration tokens

ADMIN_ACCESS_TOKEN can be found in your matrix client (e.g. Element) under `Help & About` -> `Access Token`.

Expires in 7 days and allows 1 user

```
curl -X POST \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "expires_ts": '$(( $(date +%s%N)/1000000 + 7*24*60*60*1000 ))',
    "uses_allowed": 1
  }' \
  "https://matrix.privacy.box/_synapse/admin/v1/registration_tokens/new"
```

Does not expire and allows 1 user

```
curl -X POST \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "uses_allowed": 1
  }' \
  "https://matrix.privacy.box/_synapse/admin/v1/registration_tokens/new"
```

## Delete registration tokens

```
curl -X DELETE \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN" \
  "https://matrix.privacy.box/_synapse/admin/v1/registration_tokens/TOKEN"
```