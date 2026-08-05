# Special instructions Lemmy

Lemmy is a federated link aggregator. The compose ships the backend
(`lemmy-app`, port 8536), the web frontend (`lemmy-ui`, port 1234), Postgres,
pict-rs for images and a postfix relay for signup mail. Only the backend is
ever contacted by other instances.

## Config file

`lemmy.hjson` is not generated from the `.env`. Copy it and fill it in by hand:

```
cp apps/lemmy/lemmy.example.hjson apps/lemmy/lemmy.hjson
```

Set `hostname`, `database.password` and `pictrs.api_key` to match your `.env`.
The file is gitignored.

**`hostname` is permanent.** Use the bare domain, no scheme, no port, no
trailing slash, no `www.`. It is baked into the ActivityPub id of every user,
community, post and comment your instance creates. Changing it later does not
migrate anything, it orphans all existing federated content. Decide once,
before first start.

## DNS

| Type | Name | Value | Required |
|---|---|---|---|
| `A` | `lemmy.YOUR_DOMAIN.TLD` | server's public IPv4 | yes |
| `AAAA` | `lemmy.YOUR_DOMAIN.TLD` | server's public IPv6 | only if you have v6 |
| `CAA` | `YOUR_DOMAIN.TLD` | must permit `letsencrypt.org` | only if you use CAA |

The record name must match `hostname` in `lemmy.hjson` exactly.

**Do not enable Cloudflare's proxy (orange cloud) on this record.** Bot
protection and challenge pages break ActivityPub POSTs from remote instances,
which cannot solve a JS challenge. Keep it DNS-only. Cloudflare as a DNS
provider is fine, that is what the `cloudflare-dns` cert resolver uses.

For signup mail to be delivered rather than binned, `lemmy-postfix` sends
directly and also wants an SPF `TXT` record on the subdomain
(`v=spf1 ip4:YOUR_PUBLIC_IP -all`) plus matching reverse DNS on your public IP,
set at your ISP or VPS provider. On a home line you usually get neither and
port 25 is blocked, so point `email.smtp_server` at a real submission host on
587 instead, with `smtp_login`, `smtp_password` and `tls_type: "starttls"`.

## Firewall

Inbound to the server, forwarded on the router if you are behind NAT:

| Port | Proto | Required | Why |
|---|---|---|---|
| 443 | TCP | yes | all web traffic and all inbound federation |
| 80 | TCP | recommended | HTTP to HTTPS redirect, and HTTP-01 ACME if you ever switch to it |

That is the entire list. Postgres, pict-rs and postfix sit on the compose
`internal` network and publish nothing. Do not add port mappings for them.

Outbound from the server:

| Port | Proto | Required | Why |
|---|---|---|---|
| 443 | TCP | yes | Lemmy dials remote instances to deliver and fetch |
| 53 | TCP/UDP | yes | resolving remote instance hostnames |
| 123 | UDP | yes | NTP, see below |
| 25 | TCP | only for direct mail send | often blocked by residential ISPs |

**Clock sync is a hard federation requirement.** Activities are signed with a
timestamp and remote instances discard anything more than an hour off. A
drifting clock federates intermittently in a way that looks random.

```
timedatectl status | grep -i synchron    # want: yes
```

## Verifying federation

One hostname serves two apps: browsers get HTML from `lemmy-ui`, remote
instances get JSON from `lemmy-app` based on the `Accept` header. Traefik
splits them with four routers, and `lemmy-ui` is the catch-all. If the
ActivityPub router ever fails to load, its traffic silently lands on the web UI
and remote instances get HTML, which breaks federation with nothing in the logs.

Run from outside your network. All four must return JSON, not HTML:

```
curl -H "Accept: application/activity+json" https://lemmy.YOUR_DOMAIN.TLD/u/YOUR_USER
curl -H "Accept: application/activity+json" https://lemmy.YOUR_DOMAIN.TLD/c/YOUR_COMMUNITY
curl -H "Accept: application/activity+json" https://lemmy.YOUR_DOMAIN.TLD/post/1
curl -H "Accept: application/activity+json" https://lemmy.YOUR_DOMAIN.TLD/comment/1
```

`{"@context":` is correct. `<!DOCTYPE html>` means the request hit lemmy-ui.

Check no router was dropped, which is what a bad rule looks like:

```
docker logs traefik 2>&1 | grep -i "error while parsing rule"
```

Empty output is what you want. Federation queue health, one row per remote
instance:

```
docker exec -it lemmy-postgres psql -U lemmy -d lemmy -c \
  "SELECT i.domain, fqs.fail_count FROM federation_queue_state fqs \
   JOIN instance i ON i.id=fqs.instance_id ORDER BY fqs.fail_count DESC LIMIT 20;"
```

A high `fail_count` on one domain is that instance's problem. High across
nearly all of them is yours: blocked outbound 443, clock skew, or a cert
remote instances reject.

## Notes

- Lemmy has no Redis and does not want one. The federation queue and all
  caching live in Postgres. If it is slow, the answer is Postgres, pict-rs or
  the proxy.
- Keep `lemmy` and `lemmy-ui` on the same version, they release in lockstep.
- The Postgres `command:` block is a pgtune "web" profile assuming roughly
  16 GB RAM and 4 cores for this box. Regenerate at
  <https://pgtune.leopard.in.ua> if your host differs, and keep `shm_size` at
  or above `shared_buffers`.
- `synchronous_commit=off` is deliberate. It is the biggest win for Lemmy's
  write-heavy workload, at the cost of losing a fraction of a second of
  commits on an unclean shutdown.
- Bumping `postgres:17-alpine` to 18 will not migrate the data directory.
  Postgres refuses to start on an older major version's data dir. Back up with
  `./manage.sh --backup --app lemmy` and do a dump/restore.
