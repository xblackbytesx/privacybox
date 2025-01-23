# Mastodon

## First steps
Like ususal you should create the folders as listed in the `docker-compose.yml` volumes section.

```
  mkdir -p /media/storage/docker/mastodon/{database,redis,elasticsearch,config}
```

Before starting the app make sure to run all generator commands listed in the `.env.example` and all the required env variables are populated in your `.env` file.

## Creating your admin user
Enter the running `mastodon-app` container:
```
docker exec -it mastodon-app sh
```

Once inside the container run these commands:
```
/tootctl accounts create <username> --email=<email> --confirmed --role Owner
```

```
/tootctl accounts approve <username>
```