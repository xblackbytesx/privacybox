# NetBird access scoping

The working access-control setup for the NetBird stack: which hosts on the LAN
are reachable over the tunnel, on which ports, with FQDNs maintained in exactly
one place (pfSense unbound).

Companion to `docs/netbird.md` (the server) and `docs/netbird-client.md` (the
routing peer). Reproduce the tables below in the dashboard and you have it.

Layout this assumes: server on the VPS, coruscant (`10.0.221.7`) the routing
peer on TrueNAS, pfSense unbound at `10.0.221.1:53`, clients joining from
outside the LAN.

## The configuration at a glance

| Item | Value |
|---|---|
| Network | `home-lan` |
| Routing peer | coruscant, metric 9999, masquerade **on** |
| High availability | inactive, single routing peer |
| Exit node | **none** |
| DNS zones | **none** |
| Groups | `remote` (off-LAN clients), `Routing Peers` (coruscant), `servers` (see `docs/netbird-server-peers.md`) |
| Nameserver | `Home DNS`, `10.0.221.1:53`, Match Domains empty, distributed to `remote` |

**Resources**, one per host, all `/32`, no groups assigned since policies target
them directly:

| Resource | Address |
|---|---|
| PFsense | `10.0.221.1/32` |
| Endor | `10.0.221.5/32` |
| Coruscant | `10.0.221.7/32` |

**Policies**, all unidirectional, source `remote`:

| Name | Destination | Kind | Proto | Ports |
|---|---|---|---|---|
| Allow local DNS resolves UDP | PFsense | resource | UDP | 53 |
| Allow local DNS resolves TCP | PFsense | resource | TCP | 53 |
| Endor services | Endor | resource | TCP | 80, 443 |
| Coruscant NPM TCP | Coruscant | resource | TCP | 80, 443 |
| Coruscant NPM peer | **`Routing Peers` group** | **peer** | TCP | 80, 443 |
| ICMP diagnostics, PFsense | PFsense | resource | ICMP | disabled |
| ICMP diagnostics, Coruscant | `Routing Peers` group | peer | ICMP | disabled |

Everything not listed is unreachable, and mostly has no route at all rather
than being blocked.

Servers reaching the LAN get their own group and policies, see
`docs/netbird-server-peers.md`.

## Why Networks and not Routes

Routes are for exit nodes. A route without ACL groups grants unrestricted
access. Networks are deny by default: nothing is reachable until a policy allows
it. If an exit node exists, remove it first, since a `0.0.0.0/0` route keeps the
broad path open and also overrides per-route masquerade settings (upstream
issue #5683).

## 1. Resources

One resource per host, each a single `/32` named for the device.

A resource can be a CIDR like `10.0.221.0/24`, but do not. A policy's ports
apply to the whole resource, so a subnet-wide resource means one port list for
every host in it. Per host is what lets pfSense have port 53 and nothing else
while the NAS has its own list.

A resource can also be a domain or wildcard domain. Do not use those either.
That is the FQDN duplication this design exists to avoid.

Resources need no groups here. Policies reference them directly.

Adding resources before their policies is safe. Networks are deny by default, so
a resource with no policy is simply unreachable.

## 2. Routing peer

Add coruscant. Without a routing peer the resources have no path, and the
dashboard warning about that is literal.

It attaches to the **network**, not per resource, so one assignment covers all
three. Confirm the enable-routing-peer toggle is on.

Additional routing peers are chosen by metric: a lower metric wins outright and
the other is held in reserve, while equal metrics make each client pick on
latency and only switch past a 20ms difference. With one peer there is nothing
to tune.

## 3. Groups

`remote` holds off-LAN clients. Put your **user** in it as well as the peers:
peers that user enrols are then auto-assigned to it, so a new laptop inherits
the right access without you remembering. The caveat is that this is an
automatic grant to that user's future devices, so do not add other people to
`remote` unless they should have this access.

Name it `remote` rather than something phone-shaped. What its members have in
common is being off-LAN, and you will want a laptop in it.

coruscant belongs to `Routing Peers` only. It is a destination, never a source.

## 4. Policies, and the one that catches everyone

Policies connect a source **group** to a destination. Keep them unidirectional
so only the client initiates, and resist `ALL` on the NAS: it runs the container
stack, so a wide rule there is the largest single grant in the design.

**Resource policies and peer policies are different grants.** This is the
easiest thing here to get wrong and it presents as total failure, not partial.

A resource and its policy grant the **route** to an address. They do not grant
reaching the **peer itself**. Upstream: "Reaching the peer itself is a separate
permission from reaching machines behind it." So `10.0.221.7`, which belongs to
the routing peer, needs **both** rows in the table above: the resource policy
and the peer policy targeting the `Routing Peers` group.

Without the peer policy, everything *behind* the routing peer works perfectly
while the peer itself is silently unreachable. Where a reverse proxy on that
host fronts most services, that reads as "nothing works" even though routing,
DNS and policies are all correct.

ICMP behaves the same way, which is why there are two diagnostic rows. A
resource-scoped ICMP policy will not make `ping` to the routing peer work.
Upstream notes that a service working while ping fails is the signature of a
missing ICMP policy rather than a broken route.

`NB_ENABLE_LOCAL_FORWARDING` is a red herring for this. It applies to Windows
and macOS peers, and to Linux only in netstack mode.

## 5. Pre-made policies

Delete `Default` (all peers to all peers), `Users to Routing Peers` (ALL/ALL,
bidirectional, sourced from every user) and `Users to My Resource` (wizard
generated, often with a dangling destination). The scoped policies above replace
them.

Expect the wizard to generate a fresh `Users to My Resource` if you create
another network later.

**Delete what you will never want, disable what you will want again.** Dead
defaults should go, since a disabled policy still invites someone to flip it on
to see what happens. Diagnostics are the exception: an ICMP-to-one-host policy
left in place but disabled grants nothing and is one click away when you need
it. Name those so they explain their own state.

## 6. DNS

One nameserver, `Home DNS`, `10.0.221.1:53`, distributed to `remote`.

**Match Domains stays empty**, making it a primary nameserver that handles all
domains. The tidy alternative, a match domain for just your zone, does not work
on Android: match domains are supported only on macOS, Windows 10+ and Linux
with systemd-resolved. Leaving it empty sends all DNS to pfSense, which for this
stack is arguably better anyway since your resolver and its filtering then apply
off-LAN too. The cost is that every lookup traverses the tunnel.

Set Distribution Groups to `remote`, not All. coruscant does not need it: it is
on the LAN and resolves through pfSense natively, and `apps/netbird-client`
runs with `NB_DISABLE_DNS=true`, so NetBird leaves its DNS alone (see
`docs/netbird-client.md` for why that matters).

This is why the port 53 policies come first. With a primary nameserver and no
DNS route, nothing resolves and every other rule looks broken.

## 7. Masquerade

Leave it **on**. coruscant then SNATs forwarded traffic to `10.0.221.7` and the
LAN needs no awareness of NetBird.

It does not loosen scoping. Resources and ports are enforced on the routing peer
regardless; masquerade only changes which source IP the destination sees.

Turning it off buys pfSense-side rules against real NetBird source addresses, as
a second enforcement point. It costs two things. It is a two-part change, since
without masquerade replies go to `100.64.0.0/10` which pfSense has no route for,
so a static route via `10.0.221.7` is mandatory in the same sitting. And it
slightly widens the topology, because LAN hosts can then reach client NetBird
addresses, which they currently cannot.

## Why FQDNs stay in one place

pfSense unbound is the only thing that knows names. NetBird only sees IPs.

On the LAN, DHCP hands out pfSense and nothing changes. On the tunnel, the
NetBird nameserver points at the same resolver. Same names, same answers, one
source of truth.

Three NetBird features tempt you across that line. Leave all three unused:

| Feature | Why not |
|---|---|
| Domain resource | a name, maintained in NetBird as well as pfSense |
| Wildcard domain resource | same, for a whole zone at once |
| Custom DNS Zone | NetBird's own records, and they **override** your nameserver |

Zones deserve the loudest warning because they take precedence over nameserver
groups. One for your domain silently shadows pfSense, and a stale record there
is miserable to debug: pfSense answers correctly while clients get the wrong
address.

Expect this: a name resolving to a LAN IP outside your resource list works at
home and fails on the tunnel. That is the scoping working. Add that host as a
resource with the ports it needs, never the name to NetBird.

## Verification

From a client off-LAN, NetBird connected, no exit node:

```
nslookup jellyfin.coruscant.dropdoos.nl 10.0.221.1   # pfSense answers directly
curl -sv https://jellyfin.coruscant.dropdoos.nl -o /dev/null 2>&1 | head -20
curl -sv https://immich.endor.dropdoos.nl -o /dev/null 2>&1 | head -20
```

Both curls should complete a TLS handshake and show `ALPN: server accepted h2`.
The first proves the peer policy works, the second proves resource routing does.

Then check the boundary rather than the happy path. These should fail:

```
curl -sv --max-time 10 https://10.0.221.1/ -o /dev/null   # pfSense admin, no 443 in policy
ping 10.0.221.9                                           # a host with no resource
```

Diagnosing order when something is unreachable: is there a resource for that IP,
is there a policy covering that port, is the direction right, and if the target
is the routing peer itself, is there a **peer** policy as well as a resource one.

On Android note that Termux's `dig` and `nslookup` read Termux's own
`resolv.conf`, hardcoded to `8.8.8.8`, so they never show what Android is doing.
Use `curl -v` or `ping` to see the system resolver's answer. Specifying a server
explicitly, as in the `nslookup` above, does still work.
