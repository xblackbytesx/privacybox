# privacybox-docker
Zero-config self-hosted alternatives to most popular services.

## Instructions
Installtion is incredibly simple.
Make sure the bash script is executable like this:
```
chmod +x deploy.sh
```

And simply run the script to get started:
```
./deploy.sh
```

## Monitoring & Swarm control
This project gives you two endpoints for proxy-monitoring and controlling your containers.
After succesfully running the `deploy.sh` script you should be able to visit the following subdomains:

traefik.YOUR_DOMAIN.TLD  
portainer.YOUR_DOMAIN.TLD

## Implementation status:
| App | Status | Notes |
|---|---|---|
| Nextcloud | WIP  |  No write access to data dir |
| Spotweb | WIP | Static assets get served over HTTP |
| Jackett | Done |  |
| Ghost | Done |   |
| Wordpress | Done |   |
| Hugo | Done | Only serving of public dir, no generating |
| Portainer | Done |   |
| Wallabag | WIP | Backend works, no front-end yet |
| Matrix Synapse | WIP | Untested
| Matomo | Done |   |
| Gitea | Done |   |
| Jitsi Meet | WIP | Untested |
| Invidious | WIP | Not serving page |