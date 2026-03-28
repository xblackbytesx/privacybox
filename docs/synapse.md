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

# DNS & Firewall Configuration

Replace `matrix.example.com` with your actual domain.

## DNS Records

| Hostname | Type | Value |
|----------|------|-------|
| `matrix.example.com` | A | `<your-server-ip>` |
| `matrix.example.com` | AAAA | `<your-ipv6>` *(if applicable)* |

## Firewall Inbound Rules

| Port | Protocol | Service |
|------|----------|---------|
| 80 | TCP | Traefik HTTP→HTTPS redirect |
| 443 | TCP | Traefik HTTPS (Synapse, well-known, LiveKit WS, lk-jwt) |
| 3478 | UDP | coturn TURN relay |
| 49152–49252 | UDP | coturn media relay |
| 7881 | TCP | LiveKit WebRTC control |
| 51000–52000 | UDP | LiveKit media relay |

## Notes

- All HTTPS traffic routes through port 443 via Traefik — no extra ports needed for Synapse or the LiveKit/JWT services.
- Ports 51000–52000 UDP and 7881 TCP go directly to the LiveKit container, bypassing Traefik (Traefik cannot proxy UDP, and 7881 is a direct TCP fallback path for WebRTC).
- Ports 3478 UDP and 49152–49252 UDP go directly to the host — coturn runs with `network_mode: host` so no Docker port mapping is needed, just open them in your firewall.
- No SRV record is needed. Federation is handled by `/.well-known/matrix/server`.

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
