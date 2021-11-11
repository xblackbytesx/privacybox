# Homeassistant

## Using MariaDB for a database
In your `configuration.yaml` make sure to include the following:
```
recorder:
  db_url: !secret database_connection_string
  purge_keep_days: 4
```

You can then store the connection string in your `secrets.yaml` like this:
```
mysql://homeassistant:<password>@127.0.0.1/homeassistant?charset=utf8mb4
```