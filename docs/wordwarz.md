# Special instructions WordWarZ

Server for WordWarZ, our own family word game for Android
([wordwarz-server](https://github.com/xblackbytesx/wordwarz-server), app:
[wordwarz](https://github.com/xblackbytesx/wordwarz)). It keeps the
accounts, games, turns, nudges and the scoreboard, and has a small website
for invites, devices and game replays. Containers: `wordwarz-app`,
`wordwarz-db` (Postgres).

Accounts are a username only (no email). The server is invite-only and only
admins can invite: a code shown on screen works once for 10 minutes, a link
sent by message once for 7 days.

## First run

```
cp .env.example .env                       # then fill in the blanks
mkdir -p $DOCKER_ROOT/wordwarz/database
```

There is no secret key to generate: the server stores only hashes of
passphrases and tokens. `DB_PASSWORD` is the only secret in `.env`.

Add `wordwarz` to `DEPLOYED_APPS` in `privacybox.config`, start it, then
create the first admin:

```
./manage.sh --start --app wordwarz
docker exec wordwarz-app wordwarz-server create-admin mum
docker exec -i wordwarz-app wordwarz-server set-password mum
```

`set-password` reads one line from stdin. Log in at
`https://$SUBDOMAIN.$DOMAIN`, or in the app with Play online, Log in (the
same username and passphrase). From then on Account, Invite someone (after
your fingerprint or screen lock) shows a QR code. Scanning it with the app
creates the account and signs that phone in; children never need a
passphrase. Make another admin under People if someone else should invite.

## The app

Install the APK from the
[wordwarz releases](https://github.com/xblackbytesx/wordwarz/releases)
(Obtainium can track them), then Play online, Scan a code. Another device
of the same person signs in with the code under Account, Sign in another
device in the app, or Devices on the website.

## A lost phone

People, **New phone** on the website gives a one-time sign-in code for that
person (your passphrase first; optionally signs out their other devices). Their
online games come back with it.

## Push notifications

Push goes through ntfy (UnifiedPush), never Google. Every push is encrypted
to the phone's own keys, so ntfy relays ciphertext only.

1. `WORDWARZ_PUSH_HOSTS` in `.env` names the ntfy host
   (`ntfy.privacy.box`). The server refuses endpoints on any other host.
2. ntfy's `server.yml` already allows what UnifiedPush needs
   (`everyone:up*:wo`); nothing to add for WordWarZ.
3. On each phone: install the ntfy app, sign it in to your ntfy server,
   then in WordWarZ open Account, Notifications, Turn on.

Without push, open apps still update within seconds; closed ones learn about
new moves when opened.

## DNS and ports

| Port | Where | Purpose |
|---|---|---|
| 8080 | Traefik | website and `/api/v1` |
| 5432 | internal only | Postgres |

One record for `wordwarz.DOMAIN.TLD`. Phones reach it from outside the home
network, so it needs a public record and certificate like any public app.
Open apps hold `/api/v1/changes` for up to 25 seconds; Traefik's default
timeouts allow that.

Behind Nginx Proxy Manager use `docker-compose-alt.yml` (port 8199), set
`WORDWARZ_PUBLIC_URL`, and leave the Host header as NPM sends it: browser
writes are refused when their Origin does not match it.

## Verification

```
docker compose ps                                              # both healthy
curl -fsS https://wordwarz.DOMAIN.TLD/healthz                  # ok
curl -sI https://wordwarz.DOMAIN.TLD/login | grep -i content-security-policy
docker logs wordwarz-app 2>&1 | tail -5                        # "listening"
```

Then scan an invite with the app and start a game against another account.

## Updates

Migrations run at start. `./manage.sh --update --app wordwarz` pulls
`WORDWARZ_VERSION`; pin it to a release (`0.1` or `0.1.0`) to stay on a
series. Running games keep the rules they started with.
