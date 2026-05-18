# Special instructions Headscale

Headscale is an open-source implementation of the Tailscale coordination
server. Running it on the privacybox host lets devices behind NAT (laptops,
phones, the home server/NAS) join an encrypted mesh **without opening any
ports on the home router** — every client dials outbound to
`https://hs.YOUR_DOMAIN.TLD` over 443.

The bundled compose ships two services:

- **headscale** — the coordination server. CLI-only by design; visiting
  `https://hs.YOUR_DOMAIN.TLD` in a browser correctly returns a blank page.
- **headplane** — an optional web UI for headscale, served at
  `https://hp.YOUR_DOMAIN.TLD` behind the `basic-auth@file` middleware.

Pick one of the two flows below. **Path A** is fine if you're comfortable in
a shell. **Path B** adds the web UI on top of the same headscale; nothing in
Path A becomes wrong if you later turn the UI on.

## Common setup (required for both paths)

Create the host directories and copy the headscale config in place:

```
mkdir -p ${DOCKER_ROOT}/headscale/{config,data}
cp apps/headscale/headcale.config.example.yaml ${DOCKER_ROOT}/headscale/config/config.yaml
echo '[]' > ${DOCKER_ROOT}/headscale/data/extra_records.json
chmod 664 ${DOCKER_ROOT}/headscale/data/extra_records.json
```

The `extra_records.json` file is a shared store for Headplane's "Extra DNS
records" UI tab. Headscale reads it (path set in `dns.extra_records_path`),
Headplane writes it (path set in `headscale.dns_records_path`). The file
must exist on the host before `compose up` because the compose mounts it as
a single file into the Headplane container — Docker would otherwise create
a directory at that path and the DNS tab would crash. If you're on Path A
(CLI only) and never use Headplane's DNS UI, the file just sits there
unused; no harm.

Edit `${DOCKER_ROOT}/headscale/config/config.yaml` and set:

- `server_url` to `https://hs.YOUR_DOMAIN.TLD` (must match the Traefik route
  in `apps/headscale/docker-compose.yml`).
- `dns.base_domain` to a hostname that is **not** equal to and **not** a
  parent of `server_url`'s host. Recommended pattern: `ts.YOUR_DOMAIN.TLD`.
  This name is only used inside the tailnet — no public DNS record or TLS
  certificate is needed for it.
- `derp.server.ipv4` to your VPS's public IPv4 address. The embedded DERP
  relay is enabled by default — it gives clients a fully self-hosted fallback
  path when peer-to-peer NAT traversal fails. To also use Tailscale's global
  DERP regions as backup, uncomment the entry under `derp.urls` (see
  [DERP and privacy](#derp-and-privacy) below).

Start headscale and verify the public endpoint:

```
./manage.sh --start headscale
curl https://hs.YOUR_DOMAIN.TLD/health
```

A `200 OK` from the curl means Traefik → headscale is wired correctly.

## Path A — CLI-only flow

All administration through `docker exec`. No extra setup beyond the common
section above.

Create a user (namespace for devices — pick whatever name suits you):

```
docker exec -it headscale headscale users create john
```

Issue a pre-auth key (reusable for 24 h):

```
docker exec -it headscale headscale preauthkeys create --user john --reusable --expiration 24h
```

The output `tskey-...` is what you'll paste on each device — see
[Joining devices](#joining-devices-to-the-mesh) below.

Useful day-to-day commands:

```
docker exec -it headscale headscale users list
docker exec -it headscale headscale nodes list
docker exec -it headscale headscale nodes rename --identifier <node-id> <new-name>
docker exec -it headscale headscale nodes delete --identifier <node-id>
docker exec -it headscale headscale nodes route list
docker exec -it headscale headscale nodes route enable -i <route-id>
docker exec -it headscale headscale preauthkeys list --user john
docker exec -it headscale headscale apikeys list
```

## Path B — Headplane web UI flow

Skip if you're sticking with the CLI. To enable the UI, do the common setup
first, then:

```
mkdir -p ${DOCKER_ROOT}/headscale/headplane/{config,data}
cp apps/headscale/headplane.config.example.yaml ${DOCKER_ROOT}/headscale/headplane/config/config.yaml
```

Edit `${DOCKER_ROOT}/headscale/headplane/config/config.yaml`:

- `server.cookie_secret` — must be **exactly 32 characters**. Generate with
  `openssl rand -hex 16` (16 bytes → 32 hex chars).
- `server.base_url` — `https://hp.YOUR_DOMAIN.TLD`, matching the Traefik
  route. Do not include a path.

Note: headplane v0.6+ **does not take a headscale API key in its config**.
You paste the key into the UI on first login; it's then stored as a session
cookie.

Restart the stack so headplane comes up too:

```
./manage.sh --restart headscale
```

Generate a headscale API key for the first login:

```
docker exec -it headscale headscale apikeys create
```

Open `https://hp.YOUR_DOMAIN.TLD/admin` in a browser (note the `/admin`
path — that's headplane's built-in URL prefix), pass the basic-auth prompt,
then paste the `hskey-...` value into the login screen. From here the UI
covers user creation, pre-auth keys, node list, rename, route approval,
DNS / ACL settings, etc.

The CLI commands in Path A all remain available — the UI is just a
graphical front end against the same headscale.

**Image pinning** — `apps/headscale/docker-compose.yml` pins headplane to a
specific version (`0.6.3` at time of writing). Two security advisories have
been published against headplane (a High in May 2026, a Medium in Oct 2025);
both were patched promptly. Subscribe to the
[releases feed](https://github.com/tale/headplane/releases) and bump the
pinned tag when fixes ship.

## Joining devices to the mesh

Linux / macOS / Windows — install the official Tailscale client and run:

```
tailscale up --login-server https://hs.YOUR_DOMAIN.TLD --authkey tskey-...
```

iOS / Android — install the Tailscale app and use its "alternate server"
option to point at `https://hs.YOUR_DOMAIN.TLD`, then paste the pre-auth key.

TrueNAS Scale — install the **Tailscale** app from the Apps catalog. Set:

- **Auth Key**: the `tskey-...` value
- **Extra Args**: `--login-server=https://hs.YOUR_DOMAIN.TLD`
- **Advertised Routes** (optional): `192.168.1.0/24` to make the whole home
  LAN reachable via the NAS — approve the route afterwards with
  `headscale nodes route enable`.

## Verifying the mesh

From any device joined to the tailnet:

```
tailscale status
tailscale ping <other-device-name>
```

A `direct` path means peer-to-peer NAT traversal succeeded. `relay` means
traffic is going through a DERP server — still end-to-end encrypted, just
slower. Both are valid.

## DERP and privacy

DERP (Designated Encrypted Relay for Packets) is the fallback path used when
two tailnet peers can't establish a direct WireGuard tunnel due to NAT or
firewall constraints. Payload is always end-to-end WireGuard-encrypted —
DERP only forwards opaque packets and cannot decrypt them. It does, however,
see connection metadata: who's relaying through it, how much, and when.

This compose ships with the **embedded DERP server** in headscale enabled
(region `999`, "Self-hosted VPS"). DERP HTTPS is served on the same
hostname as headscale itself (routed by Traefik), and STUN runs on **UDP
3479** on the VPS — exposed via the `ports:` block in
`apps/headscale/docker-compose.yml`. Port 3479 (instead of the IANA-default
3478) was chosen to coexist with coturn in `apps/synapse`, which also wants
3478. If you're not running the Matrix stack, you can move headscale's STUN
back to 3478 by editing `stun_listen_addr` in the config and the port mapping
in the compose.

By default `derp.urls` is empty, so **no third-party DERP relays are used**
— privacy stays fully within your VPS. If your VPS DERP becomes unreachable,
peer-to-peer is the only remaining path; if peer-to-peer also fails, the
connection is lost.

To add Tailscale's global public DERP map as a backup, uncomment the entry
under `derp.urls` in `${DOCKER_ROOT}/headscale/config/config.yaml`:

```yaml
urls:
  - https://controlplane.tailscale.com/derpmap/default
```

Restart headscale after editing. Tailscale's DERP code is BSD-3 open source,
audited, and operated by Tailscale Inc.; they see connection metadata
(public IPs, volume, timing) but never the encrypted payload.

## Common issues

**Device shows up as `invalid-xxxxx` instead of a real name.** Some
platforms (notably Android) send hostnames with capital letters or spaces
(`"Pixel 10 Pro"`). Headscale rejects anything outside `[a-z0-9.-]+` and
assigns a placeholder. Rename it once and headscale stops using the rejected
hostname:

```
docker exec -it headscale headscale nodes rename --identifier <node-id> pixel10pro
```

**`noise handshake failed` errors in headscale logs.** A client has a
cached server key from a previous headscale (typically because the
`headscale-data` volume was wiped or recreated). Logout the client and
re-enroll it with a fresh pre-auth key.

**Headplane keeps asking for an API key on every visit.** Cookie storage
problem — usually `server.cookie_secret` not being exactly 32 characters,
or `server.cookie_secure: true` with no real HTTPS between client and
Traefik. Check both.
