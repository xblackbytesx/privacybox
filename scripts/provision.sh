#!/bin/bash

echo "This script will ready a Dockerized Debian server setup"

# Environment variables
osHostname=$(hostname)

echo -n "Are you sure you want to continue? [y/n]: "
read confirmation

if [ "$confirmation" = "y" ]; then
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
	newgrp docker
	sudo systemctl enable --now docker

	echo "Installing docker-compose"
	sudo curl -L "https://github.com/docker/compose/releases/download/1.27.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	echo "Succesfully installed $(docker-compose --version)"

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
