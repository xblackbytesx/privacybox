# mautrix-whatsapp

Bridges WhatsApp into Synapse. The bridge is a linked device, so WhatsApp stays
installed on a primary phone that you open at least once every 14 days (a
GrapheneOS Private Space works).

Needs a running [Synapse](./synapse.md). Replace `privacy.box` with your domain
and run everything from the repo root.

## 1. DNS

Point `whatsapp.privacy.box` (A, plus AAAA if you use IPv6) at the server. No new
ports: Traefik already serves 80/443 and the bridge port stays internal.

## 2. Prepare

```
cp apps/mautrix-whatsapp/.env.example apps/mautrix-whatsapp/.env   # set DOMAIN, CERT_RESOLVER, DOCKER_ROOT
mkdir -p /media/storage/docker/mautrix-whatsapp/data
chown -R 1337:1337 /media/storage/docker/mautrix-whatsapp
```

## 3. Generate the config

```
(cd apps/mautrix-whatsapp && docker compose run --rm mautrix-whatsapp)
```

This writes `data/config.yaml` and exits. Use `run --rm` here and in step 5, not
`manage.sh`: the service restarts itself and would create the registration from
the unedited config.

## 4. Edit the config

Edit `/media/storage/docker/mautrix-whatsapp/data/config.yaml`. Change only these
keys and never replace the file. `apps/mautrix-whatsapp/config.example.yaml` has
the same values with comments.

| Key | Value |
|---|---|
| `homeserver.address` | `https://matrix.privacy.box` |
| `homeserver.domain` | `matrix.privacy.box` (your Synapse `server_name`) |
| `appservice.address`, `appservice.public_address` | `https://whatsapp.privacy.box` |
| `appservice.hostname` | `0.0.0.0` |
| `database.type` | `sqlite3-fk-wal` |
| `database.uri` | `file:/data/mautrix-whatsapp.db?_txlock=immediate` |
| `bridge.permissions` | replace the examples with `"matrix.privacy.box": user` and `"@you:matrix.privacy.box": admin` |
| `backfill.enabled` | `true` |
| `encryption.allow`, `encryption.default` | `true`. Decide now: existing rooms can't be encrypted later |
| `network.extev_polls` | `true`, or poll votes are dropped |
| `network.history_sync.request_full_sync` | `true`. Set it before you run `login` |

## 5. Generate the registration

```
(cd apps/mautrix-whatsapp && docker compose run --rm mautrix-whatsapp)
```

This writes `data/registration.yaml` and stores the matching tokens in
`config.yaml`. If `registration.yaml` already existed from an earlier attempt,
delete it and run this again.

## 6. Register the bridge with Synapse

```
cp /media/storage/docker/mautrix-whatsapp/data/registration.yaml \
   /media/storage/docker/synapse/data/registration-whatsapp.yaml
chown 1000:1000 /media/storage/docker/synapse/data/registration-whatsapp.yaml   # Synapse's PUID:PGID
```

In `/media/storage/docker/synapse/data/homeserver.yaml`, replace
`app_service_config_files: []` with:

```yaml
app_service_config_files:
  - /data/registration-whatsapp.yaml
```

```
./manage.sh --restart --app synapse
```

## 7. Start the bridge

```
./manage.sh --start --app mautrix-whatsapp
docker logs -f mautrix-whatsapp
```

Wait until it has started without errors.

## 8. Link WhatsApp

1. In your Matrix client, start a DM with `@whatsappbot:matrix.privacy.box`.
2. Send `login qr`, then on the primary phone open WhatsApp > Linked devices >
   Link a device and scan the code. To use a pairing code instead, send
   `login phone`.
3. If WhatsApp asks for a passkey, follow the bot's instructions.

Your chats appear as rooms and their history fills in.

## Check

- `curl -sf https://whatsapp.privacy.box/_matrix/mau/live && echo ok` prints `ok`.
- `docker logs mautrix-whatsapp` shows no `hs_token` or `M_FORBIDDEN` errors.
- `docker logs synapse-app 2>&1 | grep -i appservice` shows no ping failures.
- The bot answers `help`.
- A message sent from Matrix arrives in WhatsApp, and the other way round.
- With the Private Space locked, messages still flow.

## Optional: restrict the hostname

Only Synapse calls `whatsapp.privacy.box`, so once messaging works you can limit
it to this host. In `apps/mautrix-whatsapp/docker-compose.yml`, add the first
label and replace the existing `middlewares` line with the second:

```
- traefik.http.middlewares.mautrix-whatsapp-allow.ipallowlist.sourcerange=172.16.0.0/12, <server-public-ip>/32
- traefik.http.routers.mautrix-whatsapp-app-secure.middlewares=https-redirect@file,non-www@file,secure-headers@file,gzip-compress@file,mautrix-whatsapp-allow
```

```
(cd apps/mautrix-whatsapp && docker compose up -d)
```

Then send a message from Matrix to WhatsApp. That direction runs through this
hostname and stops working if the range is wrong, while the bridge's own calls to
Synapse are outgoing and unaffected. To get the exact address instead of a range,
enable Traefik access logs and read the source of a request for this hostname.
To undo, restore the original `middlewares` line and run `up -d` again.

## Keep it working

- Open WhatsApp on the primary phone at least every 14 days. Otherwise every
  linked device is logged out. Recovery is just `login qr` again in the same DM:
  the rooms, their history and the Synapse wiring all stay. Only messages sent
  while it was logged out can be missing, since WhatsApp decides how much history
  a new link receives.
- Update with `./manage.sh --update --app mautrix-whatsapp`. WhatsApp changes
  often and the bridge follows.
- Voice and video calls are not bridged.
- Keep it personal and low volume. WhatsApp bans accounts that look automated:
  VoIP numbers, fresh accounts, messaging non-contacts.
- Known bug: after voting on a poll in the WhatsApp app, later Matrix votes on
  that poll no longer reach WhatsApp (mautrix/whatsapp #681).

## Family members

Everyone with an account on your Synapse can use the bridge. Each person needs
their own WhatsApp number and primary phone, and runs `login` in their own DM
with the bot. Before a second person logs in:

- Switch to Postgres: add a `mautrix-whatsapp-db` service like the one in
  `apps/synapse` and point `database.uri` at it.
- Make sure encryption is on.

The bridge decrypts every message, so whoever runs the server can read them all.
Keep it to your household.
