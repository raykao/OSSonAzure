# OSSonAzure
OSS on Azure Demos framework

This project builds the framwork needed for additional demos including:
- Linux Containers on Azure with Docker, K8S and Azure Linux PaaS and .NET Core
- Azure Management integration with Application Insights and OMS for containers and Linux infrastructure
- Image creation and migration to Azure for RHEL, Centos and Ubuntu VM's
- and many more to come....

This particular project is comprised of a single shell script that has been tested to run on the following environments:
- Ubuntu Shell on Windows.  For installation instructions and please see - https://msdn.microsoft.com/en-us/commandline/wsl/install_guide 
- MacOS Sierra
- Centos 7.3
- RHEL 7

To get started with this project:
1. create a directory off of your root /source
2. clone this project from git
3. mark the script as executable
4. run the environment script

## SCRIPT to Install
```
git clone https://github.com/dansand71/OSSonAzure
sudo chmod +x ./OSSonAzure/1-build-environment.sh
./OSSonAzure/1-build-environment.sh
```

## Deploy with Docker

All versions below will run a docker container with all tools necessary already installed.  It will  

### Prerequisites

1. Docker engine installed for your OS
-- [Windows](https://store.docker.com/editions/community/docker-ce-desktop-windows)
-- [MacOS](https://store.docker.com/editions/community/docker-ce-desktop-mac)
-- Linux
--- [Centos](https://store.docker.com/editions/community/docker-ce-server-centos)
--- [Ubunutu](https://store.docker.com/editions/community/docker-ce-server-ubuntu)

1. Create/Identify the folder where you'd like to save the ssh-keys to your local computer.  In otherwords, we'll be mounting a folder from your local computer into the container, where your ssh-keys will be saved and be available for use outside of your container.

1. That's it.

### From fresh local build

You can build a fresh version from the GitHub repo (dansand71/OSSonAzure).

```:bash
# Clone github repo
git clone https://github.com/dansand71/OSSonAzure

# Change directory into new repo
cd OSSonAzure

# Build the docker image locally
docker build -t ossdemo .

# Run the new docker container
docker run -it ossdemo -v <local_asbsolute_path_to_store_ssh_keys>:/home/kenobi/.ssh

# Follow the prompts.  The Bash script (bash ./bash_scripts/02-deploy-jumpbox.new.sh) runs automatically

# Profit
```

### From docker hub hosted image (no local build necessary)

You also have the option to run directly from a prebuilt image.

```:bash
# Download and run the image hosted on docker hub
docker run -it raykao/centos_jumpbox -v <local_asbsolute_path_to_store_ssh_keys>:/home/kenobi/.ssh

# Follow the prompts.  The Bash script (bash ./bash_scripts/02-deploy-jumpbox.new.sh) runs automatically

# Profit
```

### How to start a stopped docker container

In case you need to start up a previous container again, to grab some data off of it, you can run the following commands:

```:bash

#list all docker containers (running or stopped)
docker ps -a

# Results
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                           PORTS               NAMES
e1aae3a6b246        ossdemo             "/bin/sh -c 'bash ..."   15 minutes ago      Exited (130) 3 seconds ago                           adoring_cori
27f7c0743fb4        ossdemo             "/bin/sh -c 'bash ..."   About an hour ago   Exited (130) About an hour ago                       jovial_golick
23f1bd6857ce        ossdemo             "-v /Users/raykao/..."   About an hour ago   Created                                              eloquent_boyd
c40a59931053        ossdemo             "/bin/sh -c 'bash ..."   4 hours ago         Exited (130) 3 hours ago

# Based on the timestamp or known last container that you ran - you can locate the container ID. Usually the first 2-4 are enough to identify and use the container again.
# e.g e1a for container e1aae3a6b246

# start a stopped container

docker start -t e1a

# you're now back in the previously stopped container with all the data it created

```

The script installs / updates:
- Updates YUM / APT-GET
- Installs git
- Installs Ansible
    - On Mac installs via easy_install pip
- Installs pre-reqs for Azure CLI - livffi-dev, python-dev

Configures Azure:
- Prompts for user provided server postfix which will become jumbox-{postfix}
- Creates Resource group for jumpbox server - ossdemo-utility
- Crates Network Security Group (NSG) and allows 22 and 3389 inbound - these can be limited to specific IP ranges as needed
- Creates new SSH keys in ~/.ssh directory for jumpbox server & copies these up to the server for later demo's

Once Jumpbox server (CENTOS 7.3) is created the ansible yml file:
- updates YUM
- installs ansible, git
- installs epel, python, pip
- installs docker, docker-py & sets docker to start
- installs xrdp for demo purposes and allows RDP access in to GNOME shell
- installs .NET core, Visual Studio Code
- installs pre-reqs for Azure CLI - libffi-devel, python-devel, openssl-devel
- installs autoconf, automake, developer tools
- installs GNOME - for demo purposes to show cross platform debugging



