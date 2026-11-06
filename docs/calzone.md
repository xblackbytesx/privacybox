# Special instructions CalZone

Shared household calendars and contacts with a web app, replacing Baikal.
Our own project, [calzone-server](https://github.com/xblackbytesx/calzone-server).
DAVx5 and Thunderbird sync with it over CalDAV/CardDAV. Containers:
`calzone-app`, `calzone-db` (Postgres).

It runs next to Baikal on its own subdomain. Nothing is shared between the
two; the move-over copies from Baikal, which only reads it.

## First run

```
cp .env.example .env                       # then fill in the blanks
openssl rand -hex 24                       # paste as DB_PASSWORD
head -c 32 /dev/urandom | base64           # paste as CALZONE_SECRET_KEY
mkdir -p $DOCKER_ROOT/calzone/database
```

`CALZONE_SECRET_KEY` encrypts the two-factor secrets. `.env` is in the
repo archive that every backup mode writes, so keep it there; losing it
means everyone sets two-factor sign-in up again.

Add `calzone` to `DEPLOYED_APPS` in `privacybox.config`, start it,
then create the first admin. This CLI is the only way in:

```
./manage.sh --start --app calzone
docker exec calzone-app calzone-server user add anna "Anna"
docker exec calzone-app calzone-server user admin anna on
docker exec calzone-app calzone-server user passphrase anna
```

The last command prints a temporary passphrase once. Log in at
`https://$SUBDOMAIN.$DOMAIN`: CalZone first asks you to set up two-factor
sign-in (any authenticator app; keep the recovery codes), then change the
passphrase under Settings and add everyone else under People. Each of them
sets up two-factor at their first login. Lost phone and recovery codes: an
admin picks "Reset two-factor" on People, or
`docker exec calzone-app calzone-server user two-factor-reset NAME`.

## Verify

```
curl -fsS https://calzone.DOMAIN.TLD/healthz
curl -si https://calzone.DOMAIN.TLD/.well-known/caldav | head -3
```

Expect `ok`, then a `301` to `/dav/`. The log line `CalDAV/CardDAV door on`
confirms `CALZONE_DAV` was read.

## Devices

Each person makes one password per phone or app under Devices, shown once.

| Client | Setting |
|---|---|
| DAVx5 | "Login with URL and user name": `https://calzone.DOMAIN.TLD`, user name, device password |
| Thunderbird | New calendar, On the network (and a CardDAV address book): same details |

## Moving over from Baikal

Follow [Leaving Baikal](https://github.com/xblackbytesx/calzone-server/blob/master/docs/leaving-baikal.md). In short:
Import & export, "Copy from Baikal" (admins) with
`https://baikal.DOMAIN.TLD/dav.php/` and each person's Baikal login, run it
twice (the second run must say everything is unchanged), then move every
device on the same day. Once anyone writes to CalZone, stop copying: a new
copy would overwrite their edits with Baikal's version.

## CrowdSec

Each refused sign-in logs one `auth_failure` line with the client address.
The calzone-server repo's `deploy/crowdsec/` has the acquisition, parser and
scenario to ban persistent guessers at Traefik (its `acquis.yaml` lists both
`calzone-app` and the deploy example's `calzone-server-app`). Whitelist the
home address.

## Backups and upgrades

Everything lives in Postgres under `$DOCKER_ROOT/calzone/database`,
so `./manage.sh --backup --app calzone` covers it. Each person can
also download everything as a zip under Import & export.

Pin `CALZONE_VERSION` to a release, back up, then
`./manage.sh --update --app calzone`. Migrations run at start.
