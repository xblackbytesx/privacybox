# NetBird server peers

Lets a server reach one service on the home LAN over NetBird, and nothing
else. The worked example is LiteLLM on hoth, the VPS that also runs
`apps/netbird`, calling llama-swap on coruscant at `10.0.221.7:11430`.

Builds on `docs/netbird-least-privilege.md`: the `home-lan` network, the
`Coruscant` resource and the `Routing Peers` group must already exist, with
coruscant connected as the routing peer.

## The configuration at a glance

| Item | Value |
|---|---|
| Server peer | hoth, running `apps/netbird-client` |
| Group | `servers`: hoth, no users |
| Setup key | auto-assigned group `servers` |
| Policies | two, source `servers`, TCP 11430 |
| App config | unchanged, LiteLLM keeps using `10.0.221.7:11430` |

## 1. Group and setup key

In the dashboard, Groups, create `servers`.

Put **no users** in it. A user in a group means every device that user signs
in from later joins that group. A server joins with a setup key, not a login,
so a user there only hands the server's access to your phone and laptops.

Do not reuse `remote` either. It carries the `Home DNS` nameserver, which
would route the server's DNS through your home connection, plus access a
server does not need.

Then Setup Keys, Create Setup Key, with auto-assigned group `servers`.

## 2. Run the client on the server

Deploy `apps/netbird-client` on the server as `docs/netbird-client.md`
describes, with `NB_HOSTNAME=hoth` and the key from step 1. Running a peer on
the same VPS as the NetBird server is fine.

Do not use the `docker run` line the dashboard shows under Add Peer. It has no
host networking, so the tunnel exists only inside that container. The peer
registers and looks healthy, but nothing else on the server can use it.

Host networking is what lets other containers use the tunnel. LiteLLM sits on
its own Docker networks and sends to `10.0.221.7`; the server's routing table
hands that to NetBird's `wt0` interface, and Docker rewrites the source to
hoth's NetBird IP on the way out, so the policies see hoth.

In Peers, confirm hoth is in `servers` and **not** in `remote`.

## 3. Policies

Two, both unidirectional, both needed:

| Name | Source | Destination | Kind | Proto | Ports |
|---|---|---|---|---|---|
| LiteLLM to llama-swap | `servers` | Coruscant | resource | TCP | 11430 |
| LiteLLM to llama-swap peer | `servers` | **`Routing Peers` group** | **peer** | TCP | 11430 |

`10.0.221.7` belongs to the routing peer itself, the case
`docs/netbird-least-privilege.md` warns about: the resource policy gives hoth
the route, the peer policy lets coruscant accept the traffic. With only the
first, hoth has a route and coruscant drops what arrives on it.

Control Center, Peer, hoth should now show both policies, one leading to
`Coruscant - home-lan` and one to `Routing Peers`.

A service on another LAN host, one that is not the routing peer, needs only
the resource policy. A second service on coruscant needs its own pair.

## Verification

On hoth:

```
docker exec netbird-client netbird status       # Management and Signal: Connected
ip route get 10.0.221.7                         # ... dev wt0 ...
curl -s http://10.0.221.7:11430/v1/models       # llama-swap's model list
docker exec litellm-app python -c "import urllib.request;print(urllib.request.urlopen('http://10.0.221.7:11430/v1/models',timeout=10).read()[:200])"
```

The last one proves a container gets through, not just the host. Then check
the boundary:

```
curl -s --max-time 5 http://10.0.221.7:80 -o /dev/null; echo "exit=$?"   # should fail, only 11430 is allowed
```

On coruscant, hoth should be in the peer list:

```
docker exec netbird-client netbird status -d | grep -A4 hoth
```

`Status: Idle` in that output is not a fault. Lazy connections, on by default
for accounts created on NetBird v0.74.0 or later, bring a tunnel up on the
first packet and drop it after 15 minutes without traffic, so the first
request after a quiet spell takes a second or two longer. Upstream's per-peer
switch to keep it up is `NB_LAZY_CONN=off`.

## If it does not connect

| Symptom | Cause |
|---|---|
| `ip route get` names another interface | another VPN client on the server (tailscale, say) owns that route; one mesh per host |
| hoth stuck on `Connecting`, coruscant does not list hoth | coruscant is not receiving updates: check `netbird status` there for `Management: Connected`. A peer without `NB_DISABLE_DNS=true` can lock itself out, see `docs/netbird-client.md` |
| tunnel `Connected` but `curl` times out | a policy is missing, usually the peer one |
