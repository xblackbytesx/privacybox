# Setting appropriate data folder permissions:

## Find www users `id`
```
ps -ef
```

Look for the one with the `www` permissions.
For this example we'll go with `82`.

## Set data directory permissions accordingly
```
sudo chown -R 82:82 /media/storage/nextcloud-data
```

Also be sure to set permissions restricitve so it's not public to the web:
```
sudo chmod -R 0770 /media/storage/nextcloud-data
```

## Profit!