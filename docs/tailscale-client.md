# Special instructions Tailscale client

Containerised Tailscale node that joins a self-hosted headscale tailnet. Use
this on home/Linux servers where you'd rather not install the native daemon.
For TrueNAS Scale, use the catalog app instead — this compose is aimed at
plain Docker hosts.

The container runs in `network_mode: host` so it behaves as a real peer —
the `tailscale0` interface lives on the host's network namespace, subnet
routing and exit-node modes both work. It is not on the `proxy` network and
has no Traefik labels; Tailscale isn't an HTTP service.

## First-time setup

Create the host state directory and the env file:

```
mkdir -p ${DOCKER_ROOT}/tailscale-client/state
cp apps/tailscale-client/.env.example apps/tailscale-client/.env
```

On the headscale side (your VPS), generate a pre-auth key:

```
docker exec -it headscale headscale preauthkeys create --user john --reusable --expiration 24h
```

Edit `apps/tailscale-client/.env`:

- `TS_HOSTNAME` — the device name as it'll appear in `headscale nodes list`.
  Must match the headscale hostname rules: lowercase letters, digits, hyphens,
  dots. No spaces, no uppercase.
- `TS_LOGIN_SERVER` — your headscale URL (e.g. `https://hs.privacy.box`).
- `TS_AUTHKEY` — the `tskey-...` from the command above.
- `TS_ROUTES` — leave empty for a regular peer; set to e.g.
  `192.168.1.0/24` if this node should act as a subnet router for your LAN.

Start:

```
./manage.sh --start tailscale-client
```

Verify on the host:

```
docker exec tailscale tailscale status
```

You should see your other tailnet peers listed, plus this node's own
`100.x.x.x` IP at the top.

## Three modes by environment

**Plain peer.** Default. `TS_ROUTES=` (empty). The host gets a tailnet IP and
a MagicDNS name; reachable from other tailnet members; can reach them.
Nothing else changes.

**Subnet router.** Set `TS_ROUTES=192.168.1.0/24` (your LAN). Subnet
routing and exit-node mode both require IP forwarding **on the host kernel**
— the compose can't set it because `network_mode: host` shares the host's
network namespace. One-time setup on the host:

```
sudo tee /etc/sysctl.d/99-tailscale.conf > /dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
```

Then start the container and approve the advertised route on headscale:

```
./manage.sh --start tailscale-client
docker exec -it headscale headscale nodes route list
docker exec -it headscale headscale nodes route enable -i <route-id>
```

Now any tailnet client can reach any device on the LAN, even ones without
Tailscale installed.

**Exit node.** Edit `TS_EXTRA_ARGS` in `docker-compose.yml` to append
`--advertise-exit-node`. Approve on headscale:

```
docker exec -it headscale headscale nodes exit-routes enable -i <route-id>
```

Tailnet members can then opt-in to route their internet traffic through this
host (per-client `tailscale set --exit-node=...`).

## Common issues

**`tailscale0` interface fails to come up.** Check that `/dev/net/tun`
exists on the host (`ls /dev/net/tun`). On some minimal hosts you may need
`modprobe tun` first. If `/dev/net/tun` is genuinely unavailable, fall back
to userspace mode by setting `TS_USERSPACE=true` and removing the
`devices:` and `cap_add:` blocks — at the cost of losing subnet routing and
exit-node functionality.

**Hostname appears as `invalid-xxxxx`.** Same rule as Android: lowercase
letters, digits, hyphens, dots only. Set `TS_HOSTNAME` accordingly or rename
post-enrollment with `headscale nodes rename`.

**`noise handshake failed` in headscale logs after re-enrolling.** Stop the
container, wipe its state, and re-enroll with a fresh pre-auth key:

```
./manage.sh --stop tailscale-client
sudo rm -rf ${DOCKER_ROOT}/tailscale-client/state/*
./manage.sh --start tailscale-client
```
