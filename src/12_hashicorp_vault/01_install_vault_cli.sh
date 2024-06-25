#!/bin/bash
sudo apt update
sudo apt install -y software-properties-common curl gnupg2
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update
sudo apt install -y vault
setcap cap_ipc_lock= /usr/bin/vault
