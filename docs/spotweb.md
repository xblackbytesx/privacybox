# Special instructions SpotWeb

The included Spotweb image has some special needs in order to function properly. Especially initializing a new instance has a few extra steps.

For the first run be sure to comment out the following line in the compose file:
```
- spotweb-config:/config
```

You can do this by putting a `#` in front of the line like this:
```
# - spotweb-config:/config
```

With this line commented and the compose file saved you may run the `up` command like usual:
```
docker-compose up -d
```

Once up and running visit `https://spotweb.privacy.box/install.php` to configure your instance.

The database location should be set to `spotweb-mariadb`

Leave the database root user field empty for it was created during container initialization. 