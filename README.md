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