# Special instructions Komga

Manga and comic library server. One container, one SQLite database, no
companion services. Traefik terminates TLS and routes to port 25600 in the
container, no host port is published.

Komga is the reading server only. It does not download anything, so pair it
with whatever acquisition workflow you already use and let it scan the result.

## Configuration

1. `cp .env.example .env` in `apps/komga` and fill in the blanks.
2. Create the config directory, the bind volume does not create it:
   `mkdir -p $DOCKER_ROOT/komga/config`
3. Set `MANGA_PATH` to the library root on the host. To serve western comics
   from a second location as well, uncomment `COMICS_PATH` in `.env` plus the
   matching volume and mount blocks in `docker-compose.yml`.
4. `PUID`/`PGID` must own both the config directory and the library paths.
   Komga runs as that user and writes thumbnails, metadata and its database as
   it. Getting this wrong shows up as an empty library after a scan that
   reported no errors.
5. Add `komga` to `DEPLOYED_APPS` in `privacybox.config`.
6. Point `manga.DOMAIN.TLD` at the host, same as every other app in the stack.

Komga asks a reverse proxy for `X-Forwarded-For`, `X-Forwarded-Proto` and
`X-Forwarded-Host`. Traefik sets all three on every router by default, so there
is no extra middleware and no context path to configure.

## Library layout

Komga does not parse series names out of filenames. One folder is one series,
and that rule is the whole of the data model:

```
/media/storage/books/manga/
  Berserk/
    Berserk v01.cbz
    Berserk v02.cbz
  Vinland Saga/
    Vinland Saga c001.cbz
    Vinland Saga c002.cbz
```

Files sitting loose in the library root are each treated as a one-shot series.
Sort before the first scan rather than after, because renaming a folder later
detaches the series and takes its read progress with it.

Inside the container the library is at `/data/manga`, which is the path to give
Komga when adding the library in the UI.

## Tidying names

Komga has no renamer of its own, so `apps/komga/tidy/komga-tidy.py` is the
Sonarr-style pass it is missing. It reduces a scene-named folder to the series
name, renames books to `Series vNN` or `Series cNNN` with padding computed per
series, and writes everything it strips (release group, year, scan tags) to a
`.komga-tidy.json` sidecar in the series folder.

It runs as a one-shot service with its own pinned image rather than through
`docker exec` into Komga, because the app image ships whatever toolchain its
upstream base happens to include and that can change on any version bump. The
profile keeps it out of `manage.sh --start`.

```
docker compose -f apps/komga/docker-compose.yml run --rm tidy
docker compose -f apps/komga/docker-compose.yml run --rm tidy --apply
docker compose -f apps/komga/docker-compose.yml run --rm tidy --undo /data/manga/komga-tidy-manifest-<stamp>.json
```

Dry run is the default and prints every rename it intends. Two things to do
before `--apply`:

1. Snapshot the dataset. On ZFS that is instant and is a better safety net than
   anything the script provides.
2. Confirm file hashing is on in Komga and a scan has finished. Komga re-matches
   renamed files by hash, and that is what preserves read progress, metadata and
   read lists. With no hash on record a rename reads as a delete plus an add and
   the progress is gone.

Every run writes a manifest to the library root before it touches anything, so an
interrupted run is still reversible with `--undo`. Name collisions abort the whole
run rather than the offending file: a collision means the parse is wrong, and a
half-renamed library is worse than an untouched one.

Rescan the library in Komga afterwards.

## First start

```
./manage.sh --start --app komga
```

Open `https://manga.DOMAIN.TLD`. The first account you create becomes the
admin, there is no default login. Then go to Libraries, add one, and point it
at `/data/manga`.

The first scan generates a thumbnail for every book in the library, so expect
sustained CPU load and a library that fills in gradually. Watch
`docker logs -f komga` rather than assuming it has stalled.

## Reading it on Android

Mihon plus the official Komga extension from the Keiyoushi repository. The
extension holds up to 10 servers, and read progress syncs in both directions,
so finishing a chapter on the phone marks it read on the server. Give it the
full `https://manga.DOMAIN.TLD` URL, not an IP and port.

OPDS lives at `/opds/v2` for any other client that speaks it.

For anything scripted, generate a per-user API key in the account settings and
send it as the `X-API-Key` header (Komga 1.20.0 and later). That keeps the
account password out of config files, and the key can be revoked on its own.

## Memory

Komga runs on the JVM. The default heap handles a normal library fine. If a
scan of a very large library dies partway through, uncomment
`JAVA_TOOL_OPTIONS` in `docker-compose.yml` and give it more room.

## Backups

Everything stateful is under `$DOCKER_ROOT/komga/config`: the SQLite database,
generated thumbnails and the logs. Rolling backups pick the app up
automatically once it is in `DEPLOYED_APPS`, and because rolling mode stops the
container before archiving, the database is captured cold and consistent.

The library files themselves live outside `DOCKER_ROOT` and are not part of
these backups.

## Verification

```
docker logs -f komga
```

Wait for `Started Application`, then check in order:

- `https://manga.DOMAIN.TLD` serves the login page over a valid certificate.
- The library scan finishes and the series count is non-zero.
- Cover thumbnails render in the web UI, which proves the config volume is
  writable by `PUID`.
- A book opens in the web reader, which proves the library mount is readable.
- Mihon connects and lists the same series.

If the scan reports zero series, check the ownership of `MANGA_PATH` first and
the folder-per-series layout second. Those two account for nearly every empty
library.
