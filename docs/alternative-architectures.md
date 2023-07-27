If you're running on a ARM64 based machine or some other less common architecture it's good to note that one of the core maintianers of Docker wrote a compatibility layer using Quemu that allows you to run images that don't natively build for your architecture.

You can install the layer for each architecture as follows:
```
docker run --privileged --rm tonistiigi/binfmt --install amd64
```

This ensures the `amd64` architecture copatibility layer is installed. This in turn allows you to pass the prefered architecture in the `docker-compose.yml` as follows:

```
service:
  joplin-app:
    platform: linux/amd64
    image: joplin/server:latest
    ...
```