# privacybox-docker
Zero-config self-hosted alternatives to most popular services.

## Instructions
Installation is incredibly simple and consists of either one or two stages depending on the state of your setup.

Make sure the start script is executable like this:
```
chmod +x start.sh
```

If you have a freshly installed Debian server you can opt to start the script with the `--provision` flag to install all the prerequisites neccesary to run the Docker instances.

If all you need is the Docker configuration itself you simply run this to get started:
```
./start.sh
```

If you have to install the prerequisites first simply run:
```
./start.sh --provision
```

## Monitoring & Swarm control
This project gives you two endpoints for proxy-monitoring and controlling your containers.
After succesfully running the `start.sh` script you should be able to visit the following subdomains:

traefik.YOUR_DOMAIN.TLD  
portainer.YOUR_DOMAIN.TLD

## Why these services?:
Each of these services serve a purpose of either substituting a non-free and non-privacy respecting Saas service and/or as a means to improve your overall digital independance. Most of the services are completely Open Source and peer-reviewed. A lot of the recommendations for these apps are extensively motivated at the [Prism Break](https://prism-break.org) project where security experts and community members come together to review the privacy implementations and implications of each service.

| App | Use-case |
|---|---|
| Nextcloud | Google Drive, Contacts, Calendar and Photos |
| Homeassistant | Full home-automation integration suite |
| Spotweb |  |
| Jackett | Proxy and aggregate torrent API's |
| Ampache | Substitutes: Spotify |
| Ghost | Free publishing platform |
| Wordpress | Free publishing platform |
| Hugo | Advanced static page generator |
| Portainer | Manage your containers, images etc. |
| Wallabag | Substitutes: Pocket, Instapaper |
| Matrix Synapse | Substitutes: Slack, Teams |
| Matomo | Substitutes: Google Analytics |
| Gitea | Substitutes: Github, Gitlab |
| InvoiceNinja | Substitutes: e.g. Moneybird |
| Jitsi Meet | Substitutes: Skype, Zoom |
| Invidious | Free YouTube front-end |
| PiHole |  |
| Sonarr |  |
| Radarr |  |
| Readarr |  |
| Lidarr |  |
| Prowlarr |  |
| Transmission |  |
| Node-Red |  |
| Wireguard |  |
| Netdata |  |
| Mastodon | Substitutes: Twitter |
| FireflyIII | Substitutes: Mint, AVAST Personal etc. |

## Implementation status:
| App | Status | Notes |
|---|---|---|
| Nextcloud | Done |   |
| Homeassistant | Done |   |
| Spotweb | Done | [Detailed notes](./docs/spotweb.md) |
| Jackett | Done |  |
| Ampache | Done  | [Detailed notes](./docs/ampache.md) |
| Ghost | Done |   |
| Wordpress | Done |   |
| Hugo | Done | Only serving of public dir, no generating |
| Portainer | Done |   |
| Wallabag | Done | [Detailed notes](./docs/wallabag.md) |
| Matrix Synapse | Done | [Detailed notes](./docs/matrix-synapse.md) |
| Matomo | Done |   |
| Gitea | Done |   |
| InvoiceNinja | Done | [Detailed notes](./docs/invoiceninja.md) |
| Jitsi Meet | WIP | Untested |
| Invidious | Done |   |
| PiHole | Done |   |
| Sonarr | Done |   |
| Radarr | Done |   |
| Readarr | Done |   |
| Lidarr | Done |   |
| Prowlarr | Done |   |
| Transmission | Done |   |
| Node-Red | Done |   |
| Wireguard | Done |  Some special instructions for combining with PiHole  |
| Netdata | WIP |   |
| Glances | Done |   |
| Mastodon | WIP |   |
| FireflyIII | Done |   |

## LetsEncrypt ACME support out of the box!
All of the above listed apps come equipped with the ability to request a valid LetsEncrypt Certificate on the fly. There are two ACME challenge types baked into this configuration: TLS and DNS challenge.

The goal of this project is for the end-user to simply configure a few environment variables and be granted security out of the box. However at this point some minimal and manual user configuration is still required to take advantage of this feature. In the near future most of the requirements for the TLS challenge will be fully cofigurable through a centralized `.env` file.

## Special notes for running on Synology
First off the default inotify limit on Synology is way too low to run apps like Syncthing properly. I advise raising the inotify limit to get some better performance out of file sync operations.

You can do this by setting a script to run on `boot` as user `root`:
```
sh -c '(sleep 120 && echo 204800 > /proc/sys/fs/inotify/max_user_watches)&'
```

Additionally you need to make sure the proper ports are not being occupied by Synology's own apps by again running a boot-time script as root. This script can be found over at `./traefik/freeSynologyPorts.sh`.


## TODO:
- Centralized storage of configurations and databases.
- Come up with proper backup strategy for container data.
- Centralized `.env` configuration in one way or shape.
- Lots more..

## NOTE: This is a Work in Progress
I started this project as a public project from it's first few lines of code. I do this mainly to force myself to think about secrets handling from the start rather than having it be an afterhought. Developing this way however does come with the caveat of having my sometimes embarrasing mistakes out there in public. Please feel free to point out the flaws in my configuration as I am also quite new to a setup like this.

Also feel free to use this setup for your own purposes, just know that I'm constantly updating, refactoring and fixing things in this early stage of the project. Bear with me, this will be stable and awesome at some point in the near future \m/

## Attribution
This project is in itself largely building on top of the wonderul work done in the Open Source community at large. Everything from Linux, Docker and the many volunteers that create ready-made images.

However thoughout the compilation of this project I've had lots of support from friend and fellow container fanboy Bart: [https://github.com/bartjekel](https://github.com/bartjekel).