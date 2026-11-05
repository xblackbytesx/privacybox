# Filebrowser

FileBrowser Quantum v2. The image runs as UID 1000, so `config` and `data` must be writable by that user.

## Initial setup
```
mkdir -p /media/storage/docker/filebrowser/{data,config}
cp apps/filebrowser/config.yaml.example /media/storage/docker/filebrowser/config/config.yaml
chown -R 1000:1000 /media/storage/docker/filebrowser
```

Set `auth.adminUsername` in `config.yaml` and `FILEBROWSER_ADMIN_PASS` in `.env`. The password is reapplied on every start, so change it in `.env`, not in the UI.

## Upgrading from v1 to v2

v2 moves from BoltDB to SQLite and restructures `config.yaml`. The database migration only runs once, on the first v2 start.

Stop the app and back up the v1 files:
```
docker compose -f apps/filebrowser/docker-compose.yml down
cd /media/storage/docker/filebrowser/config
mkdir -p ../v1-backup
cp -a database.db config.yaml ../v1-backup/
mv database.db database.db.old
```

Replace `config.yaml` with the example from this repo, then carry over `auth.adminUsername` and any other settings of your own. Uncomment this line under `server.database`:
```
migrateFrom: "/home/filebrowser/data/database.db.old"
```

Start it and watch the migration:
```
docker compose -f apps/filebrowser/docker-compose.yml up -d
docker logs -f filebrowser
```

## Verification

Look for `Starting migration from legacy database` in the logs, with no errors after it. Then check logins, users, shares, per-source permissions and any WebDAV or API clients at `https://files.<domain>`.

If that all works, remove `migrateFrom` from `config.yaml`, restart the app, and confirm it starts cleanly. Keep `v1-backup` until you are sure you will not roll back.

## Rollback

Stop the app, restore `database.db` and `config.yaml` from `v1-backup`, remove `database.sqlite`, and set the image tag to `1.5.8-stable`.
