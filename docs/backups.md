# Backups

All backup logic lives in `scripts/backup.sh`, invoked through `manage.sh`.
The guiding rule: **a backup that exists must be trustworthy.** Every archive
is verified before it gets its final name; anything that fails verification is
deleted, loudly.

## Modes

| Command | What happens | Downtime |
|---|---|---|
| `./manage.sh --backup` | One archive of the repo dir + `DOCKER_ROOT`. Refuses to run while any container is running. | Everything down for the whole backup |
| `./manage.sh --backup --rolling` | Per app (from `DEPLOYED_APPS`): stop → archive `DOCKER_ROOT/<app>` → verify → restart. The repo dir is archived once alongside. | Each app down only while its own archive is written |
| `./manage.sh --backup --app <name>` | The rolling treatment for a single app. | One app, briefly |

Extra flags: `--yes` skips the confirmation prompt (for cron), `--force`
overrides the running-containers guard and the free-space preflight — the
point of this tooling is that you never need it.

**Multi-deployment / variant apps.** A `DEPLOYED_APPS` entry names something
under `apps/`: a compose project directly (`baikal`,
`ghost/deployments/eli5`) or a parent directory whose subdirectories hold the
actual compose projects — variant layouts (`gluetun` →
`apps/gluetun/{openvpn,wireguard}`) and deployment layouts (`ghost` →
`apps/ghost/deployments/*`). Entries are resolved to concrete compose
projects before anything runs; variants that aren't running are queried and
left alone. The unit of *data* is always the top-level `DOCKER_ROOT/<app>`
tree, archived whole (minus excludes). All projects sharing a top are stopped
together and the tree is archived once as `<app>.tar.gz` — archiving
`DOCKER_ROOT/ghost` while another ghost deployment still runs would capture a
moving target. `--app` accepts any of these forms and always treats the whole
group.

## Scope (deliberate)

A backup is the privacybox repo (compose files, `.env`s, config — every mode
includes a full archived copy of it) plus `DOCKER_ROOT`. Nothing else. Data
under `STORAGE_ROOT` (media libraries, downloads, nextcloud-data, the
syncthing tree) is **intentionally out of scope** — it is re-acquirable or
replicated by other means. If that ever changes, add the paths as extra
sources in `scripts/backup.sh` rather than moving data under `DOCKER_ROOT`.

## Trust guarantees

- **Stopped-service enforcement.** Full mode aborts and lists the offending
  containers if anything is running. Rolling mode verifies each app's
  containers are actually gone after `down` before touching its data.
- **Moving-target detection.** GNU tar exit code 1 means a file changed while
  being read — something was still writing. The archive is discarded and the
  run fails; it is never left lying around.
- **Atomic archives.** tar writes to `<name>.tar.gz.partial`; only after
  verification is it renamed. A crash, Ctrl-C or full disk never leaves a
  plausible-looking but broken archive.
- **Verification.** `gzip -t` plus a full `tar -tzf` structural read of every
  archive, then a `.sha256` sidecar is written next to it.
- **No overwrites.** Timestamps are to the second and an existing target name
  aborts the run.
- **Space preflight.** Available space on `BACKUP_ROOT` must exceed the size
  of the most recent comparable backup + 10%.
- **Interrupted rolling runs self-heal.** If the run dies while an app is
  stopped, the exit trap restarts it (an app that was already stopped before
  the backup is backed up cold and deliberately left stopped).

### What rolling mode does NOT guarantee

Apps are archived at slightly different moments, so two apps that share state
(e.g. an app and a separately-deployed database it talks to) may be captured
at inconsistent points in time relative to each other. Each app's *own* data
is consistent. If you need one cross-app point-in-time snapshot, use full mode.

## Layout

```
BACKUP_ROOT/
├── hoth/                              # one subtree per server — sync or
│   ├── 20260713-142530-full.tar.gz    # ignore a whole host in syncthing
│   ├── 20260713-142530-full.tar.gz.sha256
│   └── 20260714-041200/               # rolling / --app mode
│       ├── privacybox-repo.tar.gz (+ .sha256)
│       ├── nextcloud.tar.gz       (+ .sha256)
│       └── ...
└── endor/
    └── ...
```

Each host writes only inside `BACKUP_ROOT/<its-hostname>/`, so several
servers can share one synced `BACKUP_ROOT` without touching each other.

Retention: set `BACKUP_KEEP=N` in `privacybox.config` to keep only the newest
N full archives and the newest N rolling run folders (counted separately).
Pruning only happens after a new backup has been created **and verified**,
and only ever inside the local host's own folder — archives synced in from
other servers are never pruned.

## Restoring

Archives store paths relative to `/` (tar strips the leading slash), so
restore from the filesystem root. Always check integrity first:

```bash
cd /media/storage/backups/20260714-041200-myhost
sha256sum -c nextcloud.tar.gz.sha256

# Restore one app's data (stop the app first!):
./manage.sh --stop --app nextcloud
sudo tar -xzpf nextcloud.tar.gz -C /
./manage.sh --start --app nextcloud
```

A full-mode archive restores the same way (`sudo tar -xzpf <archive> -C /`),
or extract selectively, e.g.
`sudo tar -xzpf <archive> -C / media/storage/docker/nextcloud`.

## Cron

Run scheduled backups **as root** — the script detects it and skips `sudo`,
so no password prompt can hang the job:

```cron
30 4 * * 1  cd /opt/privacybox && ./manage.sh --backup --rolling --yes >> /var/log/privacybox-backup.log 2>&1
```

`--yes` only skips the confirmation prompt; every safety check above still
applies. A failed run exits non-zero and states which archives (if any) can
be trusted.
