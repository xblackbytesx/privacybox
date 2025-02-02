# Pixelfed

## Environment Variables Gallore
As you've come to know and love from Privacybox our apps are always setup to have as little config as possible and be very biased. The antithesis of this approach is what the good people over at Pixelfed (or Jippi at least) had in mind with their docker setup. For their docker setup is endlessly tweakable with hundreds of variables. 

To ease the use of this app and to stick with the core value of Privacybox I've went ahead and gone through all of these variables and trimmed them down to the bare essentials. This of course means I'm taking you all along in my bias but I'd like to think I've striken a good balance here.

By doing this we remain somewhat consistent with the `.env` settings API you're used to from all our apps while underneath we map some of these to the expanded and expansive variables from pixelfed.

Before running the app you should combine our simplified `.env` and the pixelfed upstream `.pixelfed.docker.env` one by running the following command:

```
cat .privacybox.env .pixelfed.docker.env > .env
```

## Create admin account

```
docker exec -it pixelfed-web /bin/bash
```

```
/usr/bin/php /var/www/artisan user:admin
```

## Admin environment
https://pixelfed.privacy.box/i/admin/dashboard