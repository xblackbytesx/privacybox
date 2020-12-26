# Wallabag

## Important post-app upgrade step:
If you find yourself staring at a blank page after starting a new Wallabag image for the fist time there's a fat chance you need to run a database migration to complete the update:

```
docker exec -t wallabag-app /var/www/wallabag/bin/console doctrine:migrations:migrate --env=prod --no-interaction
```