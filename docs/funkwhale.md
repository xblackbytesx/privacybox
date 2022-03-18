# Funkwhale

## READ BEFORE STARTING CONTAINER!
This container is a bit out of the ordinary and requires some additional steps before being fully run the first time.

# Step 1: Initiate and migrate database
```
docker-compose pull
docker-compose up -d postgres
docker-compose run --rm api python manage.py migrate
```

# Step 2: Create admin user
```
docker-compose run --rm api python manage.py createsuperuser
```

# Step 3: Run it all
```
docker-compose up -d
```

# Importing music
Once logged into your instance create a new "Library" and save the library ID to a environment variable like this:
```
export LIBRARY_ID="ac1718d0-f60c-465d-bb95-57bcea7ee7ab"
```

Finally run the import itself:
```
docker-compose run --rm api python manage.py import_files $LIBRARY_ID "/media/storage/docker/funkwhale/data/music/" --recursive --noinput --in-place
```