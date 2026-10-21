# ntfy

## Initial setup

Create the host directories (must be owned by your `PUID:PGID`):

```
mkdir -p /media/storage/docker/ntfy/{config,cache}
chown -R 1000:1000 /media/storage/docker/ntfy
```

Drop the config in place. ntfy auto-loads `/etc/ntfy/server.yml`, which maps to `${DOCKER_ROOT}/ntfy/config/server.yml` on the host via the bind mount:

```
cp apps/ntfy/server.yml.example /media/storage/docker/ntfy/config/server.yml
chown 1000:1000 /media/storage/docker/ntfy/config/server.yml
```

The `chown` is **required**, not optional. Per the official docs:

> If using a non-root user when running the docker version, be sure to chown the server.yml, user.db, and cache.db files and attachments directory to the same uid/gid.

If the file is owned by root, ntfy may silently fall back to its built-in defaults even though `cat` and `ls` from inside the container appear to work fine — the verification under [Verify the config is actually loaded](#verify-the-config-is-actually-loaded) is the only reliable signal.

Edit `server.yml` and set `base-url` to your real hostname before starting the container.

Start it:

```
./manage.sh up ntfy
```

## Verify the config is actually loaded

ntfy has no "dump effective config" command, and the `/config.js` web-app endpoint does **not** echo server-side settings like `base-url` or `auth-default-access` — it only exposes web-app feature flags. So checking `/config.js` will mislead you. Use these instead:

1. **Force a log-level change and confirm it in the startup line.** This is the most reliable single check. Add to `server.yml`:
   ```yaml
   log-level: debug
   ```
   Restart, then:
   ```
   docker logs ntfy-app 2>&1 | head -5
   ```
   You should see `log level is DEBUG` in the `Listening on :80` line. If it still says `INFO`, the config is not being loaded. (Remove `log-level: debug` after verifying — it is very chatty.)

2. **Look for setting-specific log lines on startup**, which only appear when the relevant config keys are set:
   - `Attachment store updated: 0 attachment(s), 0 bytes` → `attachment-cache-dir` is loaded
   - `Waiting until ... to reset visitor stats` → the rate-limiter is wired up

3. **Functional check** — with `auth-default-access: deny-all`, an anonymous publish must be refused:
   ```
   curl -i -d "test" https://ntfy.privacy.box/test
   ```
   Expect `HTTP/2 401` or `403`. If you get `200`, auth is not active.

## Users, access and tokens

All three live in `server.yml` under `auth-users`, `auth-access` and
`auth-tokens`, not in the database. ntfy applies them on every start. Remove an
entry and it is deleted from `auth.db` on the next restart. The CLI cannot change
or delete anything declared there, so the file is the one place to look.

Generate the values. Both commands only print a value; neither creates a user
or touches the database. They run in a throwaway container, so they work before
the first start, when the placeholders would keep `ntfy-app` from running:

```
docker run --rm -it binwiederhier/ntfy user hash     # prompts for a password, prints $2a$10$...
docker run --rm binwiederhier/ntfy token generate    # prints a new tk_... token
openssl rand -base64 32                      # throwaway password for an app user
```

App users only authenticate with their token. Hash a random password for them
and discard it.

Apply and check. Declared entries show `(server config)`:

```
docker restart ntfy-app
docker logs ntfy-app 2>&1 | grep -i invalid   # bad hash, token or name stops startup
docker exec ntfy-app ntfy access
```

The example ships `PASTE_BCRYPT_HASH_HERE` and `tk_PASTE_TOKEN_HERE`
placeholders that ntfy rejects, so it will not start until every one is
replaced. The file now holds secrets:
`chmod 600 ${DOCKER_ROOT}/ntfy/config/server.yml`.

## Adding an app

One user and one topic per app. The app may only publish, the phone may only
subscribe. Odysseus is the worked example in `server.yml.example`:

```yaml
auth-users:
  - "odysseus:$2a$10$...:user"
auth-access:
  - "odysseus:odysseus:wo"
  - "phone:odysseus:ro"
auth-tokens:
  - "odysseus:tk_...:Odysseus reminders"
```

Restart, then give the app the token, not the password. Revoke it by deleting
its line and restarting. Never start a topic name with `up`: anyone can publish
anonymously to `up*` topics for UnifiedPush.

Test it. Expect `200`. The same request without the header should get `401` or
`403`:

```
curl -H "Authorization: Bearer tk_..." -d "test" https://ntfy.privacy.box/odysseus
```

For Odysseus, put the same topic in Settings, Reminders, ntfy topic. The
integration itself has no topic field, and its Test button publishes there.

## Migrating from CLI-created users

Record the current state and back up `auth.db` first. Provisioning edits it on
every start:

```
docker exec ntfy-app ntfy access > ~/ntfy-access-before.txt   # what to declare
docker stop ntfy-app
cp ${DOCKER_ROOT}/ntfy/cache/auth.db ${DOCKER_ROOT}/ntfy/cache/auth.db.pre-provision
```

Then:

1. Declare every existing user by the same name. ntfy adopts the existing user,
   and its password becomes the hash in the file.
2. Paste existing `tk_` tokens into `auth-tokens` unchanged. Apps holding them
   keep working.
3. Start, then run `docker exec ntfy-app ntfy access`. Grants without
   `(server config)` are old CLI leftovers. They still apply, so remove each
   with `docker exec ntfy-app ntfy access --reset <user> <topic>`, then restart
   once more.
4. Users still listed but not declared are CLI-only. Delete them with
   `ntfy user del <name>`, or declare them.

To roll back, stop the container, restore `auth.db.pre-provision` and the old
`server.yml`.
