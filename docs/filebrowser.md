# Filebrowser

## Initial setup
```
mkdir -p /media/storage/docker/filebrowser/{database,data,config}
```

To create the required initial files
```
touch /media/storage/docker/filebrowser/database/database.db
```

```
curl -L -# -o /media/storage/docker/filebrowser/config/.filebrowser.json https://raw.githubusercontent.com/filebrowser/filebrowser/refs/heads/master/docker/root/defaults/settings.json
```