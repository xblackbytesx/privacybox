# Mastodon

## First steps
Like ususal you should create the folders as listed in the `docker-compose.yml` volumes section.

```
  mkdir -p /media/storage/docker/mastodon/database /media/storage/docker/mastodon/public/system /media/storage/docker/mastodon/redis /media/storage/docker/mastodon/elasticsearch
```

## Create the database and set up mastodon user

```
docker run --name mastodon-db -v /media/storage/docker/mastodon/database:/var/lib/postgresql/data -e POSTGRES_PASSWORD=<YOUR_PASSWORD_OF_CHOICE> --rm -d postgres:14-alpine
```

```
docker exec -it mastodon-db psql -U postgres
> CREATE USER mastodon WITH PASSWORD '<YOUR_PASSWORD_AS_SET_ABOVE>' CREATEDB;
> exit
docker stop mastodon-db
```

## Run Mastodon configurator
```
docker-compose run --rm mastodon-web bundle exec rake mastodon:setup
```

At the end the terminal outputs your configuration, including secret keys. Copy and paste it into `.env.production` file in the root (also see .env.production.example).

OPTIONAL: At the very end of the configuration add the following config
Please note that running an Elasticsearch service is resource intensive. 
I recommend using this on well equipped hardware only.
```
ES_ENABLED=true
ES_HOST=mastodon-es
ES_PORT=9200
```

Your configuration now should look pretty similar to the supplied example but with your values in place.

You should now be able to run your instance the usual way.
```
docker-compose up -d
```