#!/bin/bash
set -e

if [ ! "$HOME" == "$PWD" ]; then
  echo "This script is intended to be run from the user's home path: $HOME"
  exit 1
fi

# BOOTSTRAP

# Add apt repositories
if ! grep -q "ansible/ansible" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
  sudo apt-add-repository ppa:ansible/ansible
fi
if ! grep -q "git-core/ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
  sudo apt-add-repository ppa:git-core/ppa
fi

# Upgrade packages
sudo apt-get update
sudo apt-get --assume-yes upgrade

# Install Ansible & Git
sudo apt-get --assume-yes install ansible
sudo apt-get --assume-yes install git