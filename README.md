# privacybox-docker
Zero-config self-hosted alternatives to most popular services.

## Instructions
Installation is incredibly simple and consists of either one or two stages depending on the state of your setup.

Make sure the start script is executable like this:
```
chmod +x manage.sh
```

If you have a freshly installed Debian server you can opt to start the script with the `--provision` flag to install all the prerequisites neccesary to run the Docker instances.

```
./manage.sh --provision
```

If above prerequisites have been met you can set up your containers of choice:

#### Step 1 | Create a config
You might want to base your config on the included example
```
cp -Rp privacybox.config.example privacybox.config
```
Make adjustments according to your personal situation, setup and desired containers. 


#### Step 2 | Start your stack
If you're happy with your configration you can simply run the following command to get it all started.

```
./manage.sh --start --all
```

That's it! You should be done!

#### Updating containers
The manage script provides a way to update all containers with a single command.

```
./manage.sh --update --all
```


## Monitoring & Swarm control
This project gives you two endpoints for proxy-monitoring and controlling your containers.
After succesfully running the `manage.sh --start --all` script you should be able to visit the following subdomains:

traefik.YOUR_DOMAIN.TLD  
portainer.YOUR_DOMAIN.TLD

## Why these services?:
Each of these services serve a purpose of either substituting a non-free and non-privacy respecting Saas service and/or as a means to improve your overall digital independance. Most of the services are completely Open Source and peer-reviewed. A lot of the recommendations for these apps are extensively motivated at the [Prism Break](https://prism-break.org) project where security experts and community members come together to review the privacy implementations and implications of each service.


| App | Use-case / alternative for |
|---|---|
| airsonic | Music streaming server (e.g. Spotify) |
| ampache | Musci stream server (e.g. Spotify) |
| anonaddy | E-mail aliassing/forwarding service |
| baikal | Cal/Carddav server (e.g. Google Contacts) |
| bitwarden | Password Manager (e.g. Lastpass) |
| calibre-web | |
| cryptofolio | |
| diaspora | Fedrated Social Media platform |
| dillinger | Web-based Markdown client |
| drawio | Drawing and diagram tool |
| expressvpn | |
| fireflyiii | Substitutes: Mint, AFAS Personal etc. |
| flame | |
| freshrss | |
| funkwhale | Music streaming server (e.g. Spotify) |
| ghost | Free publishing platform |
| gitea | Substitutes: Github, Gitlab |
| glances | |
| gpodder | |
| handbrake | |
| homeassistant | Full home-automation integration suite |
| huginn | |
| invidious | Free YouTube front-end |
| invoiceninja | Substitutes: e.g. Moneybird |
| irssi | |
| jackett | Proxy and aggregate torrent API's |
| jellyfin | |
| jitsi-meet | Substitutes: Skype, Zoom |
| joplin | |
| librephotos | |
| librespeed | |
| lidarr | |
| mastodon | Substitutes: Twitter |
| matomo | Substitutes: Google Analytics |
| matrix-synapse + Element | Substitutes: Slack, Teams |
| mealie | |
| minecraft-server | |
| netdata | |
| nextcloud | Google Drive, Contacts, Calendar and Photos |
| nginx-static | |
| node-red | |
| nzbget | |
| openspeedtest | |
| peertube | |
| photoprism | |
| pihole | |
| pixelfed | |
| portainer | Manage your containers, images etc. |
| prosody | |
| prowlarr | |
| pwndrop | |
| pydio-cells | |
| radarr | |
| readarr | |
| rocketchat | |
| searx | |
| sonarr | |
| spotweb | |
| standardnotes | |
| statping | |
| syncthing | |
| thelounge | |
| tokentracker | |
| tpb-proxy | |
| traefik | |
| transmission | |
| wallabag | Substitutes: Pocket, Instapaper |
| wireguard | |
| wireshark | |
| wordpress | Free publishing platform |


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