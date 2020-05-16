#!/bin/bash

echo "This script will ready a Dockerized Debian server setup"

# Environment variables
osHostname=$(hostname)
userEmail='someone@example.com'

echo -n "Are you sure you want to continue? [y/n]: "
read confirmation

if [ "$confirmation" = "y" ]; then

	echo -n "Would you like to install all available apps? [y/n]: "
	read installAll

	if [ "$installAll" = "y" ]; then
		installNextcloud="y"
		installGitea="y"
		installInvidious="y"
		installWordpress="y"

	elif [ "$installAll" = "n" ]; then
		echo -n "Would you like to install Nextcloud? [y/n]: "
		read installNextcloud

		echo -n "Would you like to install Gitea? [y/n]: "
		read installGitea

		echo -n "Would you like to install Invidious? [y/n]: "
		read installInvidious

		echo -n "Would you like to install Wordpress? [y/n]: "
		read installWordpress
	fi

	echo "Make sure apt-get is using ssl"
	echo "------------------------------"
	sudo apt-get install apt-transport-https -y

	echo "upgrading system"
	echo "----------------"
	sudo apt-get update && sudo apt-get upgrade -y
	sudo apt-get dist-upgrade -y


	echo "#################################"
	echo "#### -INSTALLING THE BASICS- ####"
	echo "#################################"
	sudo apt-get install curl gnupg2 ca-certificates python-setuptools software-properties-common git htop -y

	echo "Adding Docker repository"
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

	echo "Installing docker-ce"
	sudo apt-get update
	sudo apt-get install docker-ce
	sudo systemctl enable --now docker

	echo "Installing docker-compose"
	sudo curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	echo "Succesfully installed $(docker-compose --version)"

	echo "Setting up the Traefik container"
	docker network create proxy
	mkdir nginx-proxy
	curl -L "https://raw.githubusercontent.com/xblackbytesx/privacybox-docker/master/traefik/docker-compose.yml" -o ./nginx-proxy/docker-compose.yml
	cd ./traefik
	docker-compose up -d
	cd ../

	if [ "$installNextcloud" = "y" ]; then
		echo "Creating Nextcloud Network"
		docker network create nextcloud_network

		echo "Fetching compose file"
		mkdir ./nextcloud
		curl -L "https://raw.githubusercontent.com/xblackbytesx/privacybox-docker/master/nextcloud/docker-compose.yml" -o ./nextcloud/docker-compose.yml

		echo "Composing now"
		cd ./nextcloud
		docker-compose up -d
		cd ../
	fi

	if [ "$installGitea" = "y" ]; then
		echo "Creating Gitea Network"
		docker network create gitea

		echo "Fetching compose file"
		mkdir ./gitea
		curl -L "https://raw.githubusercontent.com/xblackbytesx/privacybox-docker/master/gitea/docker-compose.yml" -o ./gitea/docker-compose.yml

		echo "Composing now"
		cd ./gitea
		docker-compose up -d
		cd ../
	fi

	if [ "$installInvidious" = "y"]; then
		echo "Creating Invidious Network"
		docker network create invidious_network

		echo "Fetching compose file"
		git clone git@github.com:omarroth/invidious.git
		cd ./invidious
		docker-compose up -d
		cd ../
	fi

	if [ "$installWordpress" = "y"]; then
		echo "Creating Wordpress Network"
		docker network create wordpress_network

		echo "Fetching compose file"
		mkdir ./wordpress
		curl -L "https://raw.githubusercontent.com/xblackbytesx/privacybox-docker/master/wordpress/docker-compose.yml" -o ./wordpress/docker-compose.yml

		echo "Composing now"
		cd ./invidious
		docker-compose up -d
		cd ../
	fi

	echo 'Cleaning up'
	sudo apt-get clean
	sudo apt-get autoclean
	sudo apt-get autoremove -y

	echo 'All done! :D enjoy!'
	exit

elif [ "$confirmation" = "n" ]; then
	echo "Setup aborted by user"
	echo "Suit yourself man :-)"
	exit
fi
