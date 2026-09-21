# Special instructions NetBird

WireGuard mesh VPN, an alternative to the headscale stack. Two containers:
`netbird-dashboard` (UI) and `netbird-server`, which is the combined build
running Management, Signal, Relay and STUN in one process.

Everything lives on one hostname. Traefik splits it:

| Path | Goes to |
|---|---|
| `/` | dashboard |
| `/api`, `/relay`, `/ws-proxy/`, `/oauth2` | netbird-server |
| `/signalexchange.SignalExchange/`, `/management.ManagementService/` | netbird-server over h2c |

The two gRPC prefixes need `scheme=h2c` or clients fail to register. The
dashboard router carries `priority=1` so the specific path routers win.

## First run

```
cp .env.example .env
cp dashboard.env.example dashboard.env
cp config.example.yaml config.yaml
mkdir -p $DOCKER_ROOT/netbird/data
```

Replace `privacy.box` with your domain in `dashboard.env` and `config.yaml`,
then generate the three secrets in `config.yaml`:

```
openssl rand -base64 32 | tr -d '='   # server.authSecret
openssl rand -base64 32               # server.auth.sessionCookieEncryptionKey
openssl rand -base64 32               # server.store.encryptionKey
```

Add `netbird` to `DEPLOYED_APPS` in `privacybox.config`, point
`netbird.DOMAIN.TLD` at the host, and start it. Open the dashboard and create
the first user; the embedded IdP has no seeded account.

## Ports

| Port | Where | Purpose |
|---|---|---|
| 443 | Traefik | dashboard, API, relay, gRPC, embedded IdP |
| 3480/udp | published | STUN |

**3478 and 3479 are already taken on this host.** synapse runs coturn on the
host network on 3478/udp, and headscale publishes 3479/udp for its embedded
DERP relay. NetBird defaults to 3478, so `STUN_PORT` is set to 3480 in `.env`
and must match `server.stunPorts` in `config.yaml`.

`3480/udp` must be open inbound on the host firewall. It is the one thing here
that cannot go through Traefik: STUN works by telling a peer how its own
address looks from outside, so peers have to reach it directly. UDP only, the
container binds no TCP on that port.

No TURN port is needed. This deployment has no coturn, so the TCP half of the
old STUN/TURN pair does not apply. Relay traffic falls back over HTTPS to
`/relay` through Traefik, already covered by 443.

## Adding peers

```
# Linux
curl -fsSL https://pkgs.netbird.io/install.sh | sh
netbird up --management-url https://netbird.DOMAIN.TLD

# with a setup key from the dashboard, for unattended installs
netbird up --management-url https://netbird.DOMAIN.TLD --setup-key KEY
```

Android, iOS, macOS and Windows clients take the same management URL in their
settings screen.

## Verification

```
docker ps --filter name=netbird- --format '{{.Names}}\t{{.Status}}'
curl -s -o /dev/null -w '%{http_code}\n' https://netbird.DOMAIN.TLD
curl -s https://netbird.DOMAIN.TLD/api/healthz
docker logs --tail 50 netbird-server
netbird status                      # on a joined peer
```

`netbird status` should show `Management: Connected` and `Signal: Connected`.
If Management connects but Signal does not, the h2c scheme on the gRPC router
is the first thing to check.

## Notes

The combined image cannot use an external identity provider. Dex is embedded,
always enabled, and overrides any OIDC settings in `dashboard.env`. If you ever
want Zitadel, Keycloak or Pocket ID in front of this, you have to move to the
five-container split (management, signal, relay, dashboard, coturn), which is a
different compose file.

Storage is SQLite, and there are three separate databases under
`$DOCKER_ROOT/netbird/data`: the management store, the embedded Dex IdP
(`idp.db`), and the activity event log (`events.db`). Upstream is explicit that
SQLite is fine for smaller teams and that migrating is not required.

If you outgrow it, `server.store.engine` takes Postgres or MySQL and there is a
documented migration using `pgloader`, so this is not a one-way door. Note that
the three databases migrate independently, and the event store has historically
stayed on SQLite even when the management store is on Postgres.

`manage.sh --backup` archives `$DOCKER_ROOT/netbird` whole, which covers all
three. Sensitive fields in the management store are encrypted with
`server.store.encryptionKey` from `config.yaml`, which lives outside that
archive. Back up `config.yaml` alongside it or the restore comes back missing
exactly the secrets that matter.

Selecting a peer as an exit node gives every NetBird client the whole LAN. To
scope that down to specific hosts and ports without duplicating FQDNs, see
`docs/netbird-least-privilege.md`.

This runs alongside headscale rather than replacing it. Both can be deployed at
once, on separate hostnames and separate STUN ports, which is the point of
trialling it. Running two mesh VPN clients on the same peer works but each
manages its own routes, so expect to pick one per device.
