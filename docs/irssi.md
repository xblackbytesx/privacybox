# Irssi HOWTO

## Jump into a chat session:
After starting up the docker container run the following:
```
docker exec -it irssi-app /usr/local/bin/irssi
```

If you want to have your chat be more persistent in the background try running it in a `screen`. If you don't have screen installed you should do so before. An example of running it inside a screen:
```
screen docker exec -it irssi-app /usr/local/bin/irssi
```

This way when you detach (`CTR+A` then `D`) the screen with your chats are still running and you can return to them using `screen -r`.
