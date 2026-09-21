# Special instructions NetBird client

Containerised NetBird peer for joining a machine to your self-hosted NetBird
network without installing anything at the system level. Runs on the machine
that joins, and that can be the VPS hosting `apps/netbird` too: see
`docs/netbird-server-peers.md` for a server reaching a LAN service.

Its main use here is as a **routing peer**: one Linux peer that forwards traffic
between the NetBird mesh and a LAN, so you reach everything on that network
without a client on every device.

## Setup

In the dashboard, Setup Keys, Create Setup Key. Then on the target machine:

```
cp .env.example .env       # fill in NB_HOSTNAME, NB_MANAGEMENT_URL, NB_SETUP_KEY
mkdir -p $DOCKER_ROOT/netbird-client/state
docker compose up -d
```

The peer appears in the dashboard within a few seconds. The setup key is only
read on first registration; state lives in the mounted volume afterwards.

Use this compose rather than the `docker run` line the dashboard shows under
Add Peer. That line has no host networking, so the tunnel exists only inside
its own container: the peer registers and looks healthy, but nothing else on
the machine can use it.

## Making it a routing peer

**Nothing about this is configured here.** Unlike Tailscale, where the client
advertises routes with `--advertise-routes`, NetBird defines routes server-side
and assigns them to a peer.

In the dashboard, Networks, create a network, add a Route with the CIDR you want
reachable (your LAN, say `192.168.1.0/24`), and set this peer as the routing
peer. To make it an exit node instead, use the peer's Add Exit Node action,
which is a `0.0.0.0/0` route under the hood.

Only Linux peers can be routing peers, so a NAS is a good fit.

## Requirements on the host

`network_mode: host` is required for a routing peer. It needs to see the LAN
directly, which a bridge network cannot do.

The three capabilities (`NET_ADMIN`, `SYS_ADMIN`, `SYS_RESOURCE`) are what
upstream documents for the rootful client; `SYS_ADMIN` is needed for its eBPF
paths. There is a `rootless-latest` image with a userspace WireGuard stack and a
smaller blast radius, but upstream states that LAN routing needs the rootful
deployment.

`NB_ENABLE_LOCAL_FORWARDING` is deliberately **not** set. Upstream scopes it to
Windows and macOS peers plus Linux in netstack mode, and this peer is Linux in
kernel mode, so it is a no-op here. It was tried while chasing the routing-peer
limitation described in `docs/netbird-least-privilege.md` and changed nothing.

IP forwarding must be on. It is a **host** sysctl, and Docker refuses
container-level sysctls when host networking is in use, so it cannot be set from
this compose file. In practice Docker enables it itself for bridge networking,
so on any box already running Docker it is almost certainly on. Check:

```
sysctl net.ipv4.ip_forward       # want 1
```

If it is 0, that is the one host-level change this needs.

`NB_DISABLE_DNS=true` keeps NetBird out of DNS. With host networking the
client can only change DNS inside its own container, so the only lookups it
ever affects are its own, including the one for `netbird.DOMAIN.TLD`. If its
resolver stops answering, the peer can no longer find the server and stays
disconnected: `netbird status` shows `Management: Disconnected` and the log
repeats `lookup netbird.DOMAIN.TLD on <its own NetBird IP>:53 ... i/o
timeout`. The host resolves through its normal DNS either way. When adding
the setting to an existing peer, recreate the container (on TrueNAS, redeploy
the app) rather than restarting it, so it starts from a clean
`/etc/resolv.conf`.

## TrueNAS

TrueNAS 25.10 Apps is Docker based, so deploy this as a custom app from YAML
rather than through the catalogue. Host networking and added capabilities are
both permitted there.

Point `DOCKER_ROOT` at a dataset path on your pool, not the VPS layout. Keeping
the state on a pool dataset means the peer survives app redeploys and keeps its
identity, so it does not consume a fresh setup key each time.

## Verification

```
docker exec netbird-client netbird status
docker exec netbird-client netbird status -d      # per-peer detail
docker logs --tail 30 netbird-client
```

Expect `Management: Connected` and `Signal: Connected`. In the detailed output,
each peer shows either `P2P` or `Relayed`. Relayed everywhere usually means
inbound UDP on the STUN port is blocked, see `docs/netbird.md`.

`Idle` is not a fault either. Lazy connections bring a tunnel up on the first
packet and drop it after 15 minutes without traffic.

From another peer, ping something on the routed LAN that is not the NAS itself.
That is the check that the route works rather than just the peer.

## Notes

This can run alongside a `tailscale-client` container on the same machine. Both
create their own interface and manage their own routes, so avoid advertising the
same LAN CIDR through both at once or the host ends up with competing routes.
