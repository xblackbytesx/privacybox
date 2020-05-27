#!/bin/bash

echo "This script will ready a Dockerized Debian server setup"

# Environment variables
osHostname=$(hostname)
userEmail='john.doe@privacy.box'

echo -n "Are you sure you want to continue? [y/n]: "
read confirmation

if [ "$confirmation" = "y" ]; then

	export $(grep -v '^#' .env | xargs -d '\n')

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
	echo "#### ~INSTALLING THE BASICS~ ####"
	echo "#################################"
	sudo apt-get install curl gnupg2 ca-certificates python-setuptools software-properties-common git htop -y

	echo "Adding Docker repository"
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

	echo "Installing docker-ce"
	sudo apt-get update
	sudo apt-get install docker-ce
	sudo gpasswd -a $USER docker
	sudo systemctl enable --now docker

	echo "Installing docker-compose"
	sudo curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	echo "Succesfully installed $(docker-compose --version)"


	echo "#######################"
	echo "#### ~DOCKER TIME~ ####"
	echo "#######################"

	echo -n "What should be your main domain? [privacy.box]: "
	read globalDomain

	echo -n "What should be your main email address? [john.doe@privacy.box]: "
	read globalEmail

	echo -n "What should be the global database 'root' password? [secret]: "
	read globalDbRootPass

	echo -n "What should be the global database 'user' password? [secret]: "
	read globalDbUserPass

	echo -n "What should be the data storage root folder? [/media/storage]: "
	read globalStorageRoot

	if [ -z "$globalDomain" ]; then
		globalDomain='privacy.box'
	fi

	if [ -z "$globalEmail" ]; then
		globalEmail='john.doe@privacy.box'
	fi

	# TODO: Make this list configurable
	declare -a appsToInstall=("traefik" "portainer" "sonarr" "radarr" "jackett" "spotweb" "transmission" "nzbget")

	for app in ${appsToInstall[@]}; do
		echo "Setting up the ${app^} container"
		cd ./$app

		cp .env.example .env

		sed -i 's/DOMAIN=privacy.box/DOMAIN='$globalDomain'/g' .env
		sed -i 's/EMAIL=john.doe@privacy.box/DOMAIN='$globalEmail'/g' .env

		if [ "$app" == "traefik"]; then
			sed -i 's/email: john.doe@privacy.box/email: '$globalEmail'/g' ./data/traefik.yml
			sed -i 's/email: john.doe@privacy.box/email: '$globalEmail'/g' ./data/traefik.yml
		fi

		if [ "$globalDbRootPass" ]; then
			sed -i 's/ROOT_PASS=secret/ROOT_PASS='$globalDbRootPass'/g' .env
		fi

		if [ "$globalDbUserPass" ]; then
			sed -i 's/USER_PASS=secret/USER_PASS='$globalDbUserPass'/g' .env
		fi

		if [ "$globalStorageRoot" ]; then
			sed -i 's/STORAGE_ROOT=\/media\/storage/STORAGE_ROOT='$globalStorageRoot'/g' .env
		fi

		echo "Proposed ${app^} configuration:"
		echo "----------------"
		echo ""
		cat .env
		echo ""
		echo "----------------"

		echo -n "Customize ${app^} install? [n]: "
		read _customizeInstall

		if [ "$_customizeInstall" = "y" ]; then
			source config.sh;
		fi

		echo "Effective ${app^} configuration:"
		echo "----------------"
		echo ""
		cat .env
		echo ""
		echo "----------------"

		echo "Starting ${app^} containers"
		docker-compose up -d

		echo "POW!! Done!... NEXT!"

		cd ../
	done

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
