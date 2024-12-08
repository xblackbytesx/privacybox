# Bluesky PDS Extra steps: 
Currently the Bluesky PDS container does not contain the neccesary admin tools you need in order to actually create an account (yet).
This is why some additional steps are needed in order to get you properly started and to generate your Decentralized Identifier or better known as `DID`.

## Step 1: generate your user/DID
After setting the proper values in your `.env` file feel free to start the container like usual.
Once it's running go to the main app dir for bluesky-pds (`privacybox/apps/bluesky-pds`).

Inside this folder you are going to pull a Git repository:
```
git clone https://github.com/bluesky-social/pds admin-tools
```

You then go inside this folder and travel to the `pdsadmin` folder within that.
```
cd admin-tools/pdsadmin
```

Before running these commands you need to ensure you have the `jq` and `xxd` packages installed on your system. Ideally containers pose no requirement on the host machine but this is early days for PDS still. In the future it should be incorporated within the container.

Now it's time to actually generate your DID user. Be sure to still be within the `pdsadmin` folder when running this command.
```
PDS_ENV_FILE=../../.env ./account.sh create john@privacy.box john.privacy.box
```
This command takes two arguments where the first is your desired email address (which can be any you like and is not bound to the domain of your PDS).
The second is your desired handle, this one also isn't neccesarily tied to the domain where your pds is running but you do have to own the domain to set the proper DNS settings.

## Step 2: Configure your DNS
For every domain you would like to use you need to configure the following `TXT` records in your DNS:
```
_atproto. with a value of "did=<your_full_did>"
_atproto.john with a value of "did=<your_full_did>"
```

Ideally you would also create a traefik `.well-known` route for each of your "users" so both DNS and HTTP verification work (for examples on how to do so see the privacybox docker-compose.yml file for bluesky-pds).
You can check if it works correctly over at the Bluesky debug tool: https://bsky-debug.app/handle?handle=john.privacy.box

## Step 3: Login and enjoy Bluesky!

Bit shout-out to Matt Dyson for his way more detailed and advanced tutorial on how to run Bluesky PDS properly: https://mattdyson.org/blog/2024/11/self-hosting-bluesky-pds

For Privacybox I've made sure to put all of this into a consistent and well fitting biased configuration to ease with the setup but there is more possible for those that want to tinker and I advise you to read his blog mentioned above.