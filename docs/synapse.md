# Special instructions Synapse

Matrix homeserver with Element Call. Containers: `synapse-app`, `synapse-db`,
`synapse-redis` (Valkey), `synapse-coturn`, `synapse-well-known`,
`synapse-livekit`, `synapse-lk-jwt`. `synapse-mas` is optional and commented out.

Real configuration lives in `$DOCKER_ROOT/synapse/data/homeserver.yaml`, not in
`.env`. The image reads almost nothing from the environment, so changing
`DB_USER_PASS` alone will break the connection until you edit that file to match.

## First run

```
cp .env.example .env                        # then fill in the blanks
mkdir -p $DOCKER_ROOT/synapse/{database,data,media,coturn,redis}
docker compose run --rm synapse-app generate
```

Merge `homeserver.example.yaml` into the generated
`$DOCKER_ROOT/synapse/data/homeserver.yaml`, then:

```
cp livekit.example.yaml livekit.yaml        # same key/secret as .env
cp -r well-known.example well-known         # edit both files for your domain
```

Add `synapse` to `DEPLOYED_APPS` in `privacybox.config` and start it.

## Admin API access

`/_synapse/admin` is not routed through Traefik. Run everything below from a
shell on the host, where `synapse-app` binds `127.0.0.1:8008`.

Create the first admin user:

```
docker exec -it synapse-app register_new_matrix_user \
  -c /data/homeserver.yaml http://localhost:8008
```

Get an access token for the rest of the commands:

```
export MXHOST=http://127.0.0.1:8008
export TOKEN=$(curl -s -XPOST $MXHOST/_matrix/client/v3/login \
  -d '{"type":"m.login.password","identifier":{"type":"m.id.user","user":"admin"},"password":"PASSWORD"}' \
  | jq -r .access_token)
export AUTH="Authorization: Bearer $TOKEN"
```

## Users

```
# create or update, omit "admin" for a normal user
curl -XPUT -H "$AUTH" $MXHOST/_synapse/admin/v2/users/@bob:DOMAIN.TLD \
  -d '{"password":"secret","admin":false}'

# list
curl -H "$AUTH" "$MXHOST/_synapse/admin/v2/users?from=0&limit=50"

# promote to admin
curl -XPUT -H "$AUTH" $MXHOST/_synapse/admin/v1/users/@bob:DOMAIN.TLD/admin \
  -d '{"admin":true}'

# reset password, logs out all devices
curl -XPOST -H "$AUTH" $MXHOST/_synapse/admin/v1/reset_password/@bob:DOMAIN.TLD \
  -d '{"new_password":"secret","logout_devices":true}'

# deactivate, erase:true also wipes profile and messages
curl -XPOST -H "$AUTH" $MXHOST/_synapse/admin/v1/deactivate/@bob:DOMAIN.TLD \
  -d '{"erase":true}'
```

## Registration tokens

`registration_requires_token: true` is set, so new users need one.

```
# create, empty body gives a random token with unlimited uses
curl -XPOST -H "$AUTH" $MXHOST/_synapse/admin/v1/registration_tokens/new -d '{}'

# one-use token valid until tomorrow
curl -XPOST -H "$AUTH" $MXHOST/_synapse/admin/v1/registration_tokens/new \
  -d "{\"uses_allowed\":1,\"expiry_time\":$(date '+%s000' -d 'tomorrow')}"

# list
curl -H "$AUTH" $MXHOST/_synapse/admin/v1/registration_tokens

# delete
curl -XDELETE -H "$AUTH" $MXHOST/_synapse/admin/v1/registration_tokens/TOKEN
```

## Config keys that fail silently

Synapse ignores unknown config rather than rejecting it, so a wrong key looks
exactly like a working one.

| Wrong | Right |
|---|---|
| `matrix_rtc: {enabled: true}` | `matrix_rtc: {transports: [...]}` plus `experimental_features.msc4143_enabled` |
| `content_repository: {url_preview_url_blacklist: []}` | `url_preview_url_blacklist` at top level |
| `federation_domain_blacklist` | Does not exist. Only `federation_domain_whitelist`, an allowlist |
| `msc3266_enabled` | Gone, the room summary API is unconditional |
| `experimental_features.msc3861` | Removed in 1.157.0, use `matrix_authentication_service` |
| `cp_max: 300` | `cp_max: 10`, Postgres defaults to 100 connections |

## DNS

```
A/AAAA   matrix.DOMAIN.TLD          -> host
```

`well-known/matrix/server` must be `matrix.DOMAIN.TLD:443` and
`well-known/matrix/client` must carry the same base URL clients use. Both must
agree with `server_name`. Forward and reverse DNS must also agree for
`matrix.DOMAIN.TLD` or federation partners will distrust the server.

## Ports

| Port | Where | Purpose |
|---|---|---|
| 8008 | Traefik, plus `127.0.0.1` on the host | client and federation API |
| 3478/udp, 49152-49252/udp | host network | coturn |
| 7881/tcp, 51000-52000/udp | published | LiveKit media |
| 7880 | Traefik | LiveKit signalling |

The LiveKit UDP range bypasses Traefik on purpose, see `docs/docker-tuning.md`.

## Verification

```
docker logs synapse-app 2>&1 | tail -40          # expect "listening on TCP port 8008"
curl -s https://matrix.DOMAIN.TLD/_matrix/client/versions
curl -s https://matrix.DOMAIN.TLD/.well-known/matrix/client
curl -s https://matrix.DOMAIN.TLD/.well-known/matrix/server
curl -s -o /dev/null -w '%{http_code}\n' https://matrix.DOMAIN.TLD/_synapse/admin/v1/server_version
docker exec synapse-redis valkey-cli info keyspace
```

The admin check should return `404`, meaning the path is not routed publicly.
Run `federationtester.matrix.org` for delegation and certificates.

## Notes

Calls run in widget mode via LiveKit, lk-jwt and the `rtc_foci` advertisement.
There is no standalone Element Call container: upstream scopes standalone mode to
its own dedicated homeserver with open registration and federation disabled.

To enable MAS, generate its config and fill in the DSN, public base URL and
`matrix.secret`, then uncomment the `synapse-mas` service and the
`matrix_authentication_service` block in `homeserver.yaml`:

```
docker run --rm ghcr.io/element-hq/matrix-authentication-service:latest \
  config generate > mas-config.yaml
```

MAS reads no `MAS_*` environment variables beyond `MAS_CONFIG`. With MAS on, add
`org.matrix.msc2965.authentication` to `well-known/matrix/client`;
`well-known.example/matrix/client-with-mas` has it.

`manage.sh --backup` archives `$DOCKER_ROOT/synapse` including the signing key,
which is the server identity and cannot be regenerated. Treat it accordingly.
