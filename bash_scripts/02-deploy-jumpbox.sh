#!/bin/bash

SOURCEDIR=$(dirname $BASH_SOURCE)
#Script Formatting
RESET="\e[0m"
INPUT="\e[7m"
BOLD="\e[4m"
YELLOW="\033[38;5;11m"
RED="\033[0;31m"
DEBUG="no"

# Jumpbox server variables
JUMPBOX_SERVER_PREFIX=""
JUMPBOX_ADMIN_NAME=""
JUMPBOX_ADMIN_PASSWORD=""

# Azure deployment variables
AZ_RESOURCE_GROUP="ossdemo-utility"
AZ_LOCATION="eastus"
AZ_STORAGE_PREFIX="ossdemostorage"

clear

### START JUMPBOX_SERVER USER DEFINED DETAILS ###
echo -e "${BOLD}Set values for creation of resource groups and jumpbox server${RESET}"
# Check the validity of the name (no dashes, spaces, less than 8 char, no special chars etc..)
# Can we set a Enviro variable so if you want to rerun it is here and set by default?

# JUMPBOX_SERVER_PREFIX
echo ".Please enter your unique server prefix: (Jumpbox server will become:'jumpbox-PREFIX')"
echo "     (Note - values should be lowercase and less than 8 characters.)"
read -p "$(echo -e -n "${INPUT}.Server Prefix:${RESET}")" JUMPBOX_SERVER_PREFIX
JUMPBOX_SERVER_PREFIX=$(echo "${JUMPBOX_SERVER_PREFIX}" | tr '[:upper:]' '[:lower:]')

# JUMPBOX_ADMIN_NAME
echo ".Please enter your new admin username:"
echo "     (Note - values should be lowercase and less than 8 characters.)" 
read -p "$(echo -e -n "${INPUT}.Admin Name:${RESET}")" JUMPBOX_ADMIN_NAME
# This requires a newer version of BASH not avialble in MAC OS - JUMPBOX_SERVER_PREFIX=${JUMPBOX_SERVER_PREFIX,,} 
JUMPBOX_ADMIN_NAME=$(echo "${JUMPBOX_ADMIN_NAME}" | tr '[:upper:]' '[:lower:]')

# JUMPBOX_ADMIN_PASSWORD
while true
do
  read -s -p "$(echo -e -n "${INPUT}.New Admin Password for Jumpbox:${RESET}")" JUMPBOX_ADMIN_PASSWORD
  echo ""
  read -s -p "$(echo -e -n "${INPUT}.Re-enter to verify:${RESET}")" JUMPBOX_ADMIN_PASSWORD_CONFIRM
  
  if [ $JUMPBOX_ADMIN_PASSWORD = $JUMPBOX_ADMIN_PASSWORD_CONFIRM ]
  then
     break 2
  else
     echo -e ".${RED}Passwords do not match.  Please retry. ${RESET}"
  fi
done
### END JUMPBOX_SERVER USER DEFINED DETAILS ###




### START AZURE USER DEFINED DETAILS ###
# Check the validity of the name (no dashes, spaces, less than 8 char, no special chars etc..)"
# Can we set a Enviro variable so if you want to rerun it is here and set by default?

echo ".Please enter your unique storage prefix: (Storage Account will become: 'PREFIX-storage'')"
echo "      (Note - values should be lowercase and less than 8 characters.)"
read -p "$(echo -e -n "${INPUT}.Storage Prefix? (default: ${JUMPBOX_SERVER_PREFIX}demostorage):"${RESET})" AZ_STORAGE_PREFIX

[ -z "${AZ_STORAGE_PREFIX}" ] && AZ_STORAGE_PREFIX=${JUMPBOX_SERVER_PREFIX}

AZ_STORAGE_PREFIX=$(echo $JUMPBOX_SERVER_PREFIX$AZ_STORAGE_PREFIX | cut -c1-24)

echo ""
echo -e "${BOLD}Creation of Resource Group...${RESET}"
read -p "$(echo -e -n "${INPUT}Deploy Template to create resource group, and network rules? [Y/n]:"${RESET})" continuescript
if [[ $continuescript != "n" ]]; then
    #Make a copy of the template file
    cp ${SOURCEDIR}/environment/ossdemo-utility-template.json ${SOURCEDIR}/environment/ossdemo-utility.json -f
    #MODIFY line in JSON TEMPLATES
    sudo sed -i -e "s@VALUEOF-UNIQUE-SERVER-PREFIX@${JUMPBOX_SERVER_PREFIX}@g" ${SOURCEDIR}/environment/ossdemo-utility.json
    sudo sed -i -e "s@VALUEOF-UNIQUE-STORAGE-PREFIX@${AZ_STORAGE_PREFIX}@g" ${SOURCEDIR}/environment/ossdemo-utility.json

    #BUILD RESOURCE GROUPS
    echo ".BUILDING RESOURCE GROUPS"
    echo "..Starting:"$(date)
    echo '..create utility resource group'
    read -p "$(echo -e -n "${INPUT}Resource group name: (default: ${AZ_RESOURCE_GROUP}):"${RESET})" AZ_RESOURCE_GROUP
    read -p "$(echo -e -n "${INPUT}Deployment region: (default: ${AZ_LOCATION}):"${RESET})" AZ_LOCATION

    ~/bin/az group create --name ossdemo-utility --location ${AZ_LOCATION}

    #APPLY TEMPLATE
    echo ".APPLY ARM Template"
    echo "..Starting:"$(date)
    echo '..Applying Network Security Group for utility Resource Group'
    az group deployment create --resource-group ${AZ_RESOURCE_GROUP} --name InitialDeployment --template-file ${SOURCEDIR}/environment/ossdemo-utility.json
fi

echo ""
echo -e "${BOLD}Creation of Jumpbox server...${RESET}"
read -p "$(echo -e -n "${INPUT}Create jumpbox server? [Y/n]:"${RESET})" continuescript
if [[ $continuescript != "n" ]]; then
    #Looking for jumpbox ssh key - if not found create one
    echo ".We are creating a new VM with SSH enabled.  Looking for an existing key or creating a new one."
    if [ -f ~/.ssh/jumpbox_${JUMPBOX_SERVER_PREFIX}_id_rsa ]
    then
        echo "..Existing private key found.  Using this key ~/.ssh/jumpbox_${JUMPBOX_SERVER_PREFIX}_id_rsa for jumpbox creation"
    else
        echo "..Creating new key for ssh in ~/.ssh/jumpbox_${JUMPBOX_SERVER_PREFIX}_id_rsa"
        #Create key
        ssh-keygen -f ~/.ssh/jumpbox_${JUMPBOX_SERVER_PREFIX}_id_rsa -N "" -q
        #Add this key to the ssh config file 
    fi
    if grep -Fxq "Host jumpbox-${JUMPBOX_SERVER_PREFIX}.eastus.cloudapp.azure.com" ~/.ssh/config
    then
        # Replace the server with the right private key
        # BUG BUG - we need to actually replace the next three lines with new values
        # sed -i "s@*Host jumpbox-${JUMPBOX_SERVER_PREFIX}.eastus.cloudapp.azure.com*@Host=jumpbox-${AZ_SERVER_PREFIX}.eastus.cloudapp.azure.com IdentityFile=~/.ssh/jumpbox_${AZ_SERVER_PREFIX}_id_rsa User=${JUMPBOX_ADMIN_NAME}@g" ~/.ssh/config
        echo "..We found an entry in ~/.ssh/config for this server - do not recreate."
    else
        # Add this to the config file
        echo -e "Host=jumpbox-${JUMPBOX_SERVER_PREFIX}.eastus.cloudapp.azure.com\nIdentityFile=~/.ssh/jumpbox_${JUMPBOX_SERVER_PREFIX}_id_rsa\nUser=${JUMPBOX_ADMIN_NAME}" >> ~/.ssh/config
    fi

    sudo chmod 600 ~/.ssh/config
    sudo chmod 600 ~/.ssh/jumpbox*
    sshpubkey=$(< ~/.ssh/jumpbox_${JUMPBOX_SERVER_PREFIX}_id_rsa.pub)
    
    #Delete the host name in case it already exists
    ssh-keygen -R "jumpbox-${JUMPBOX_SERVER_PREFIX}.eastus.cloudapp.azure.com"

    #CREATE UTILITY JUMPBOX SERVER
    echo ""
    echo "Creating CENTOS JUMPBOX utility machine for RDP and ssh"
    echo ".Starting:"$(date)
    echo ".Reading ssh key information from local jumpbox_${JUMPBOX_SERVER_PREFIX}_id_rsa file"
    echo ".--------------------------------------------"
    azcreatecommand="-g ossdemo-utility -n jumpbox-${JUMPBOX_SERVER_PREFIX} --public-ip-address-dns-name jumpbox-${JUMPBOX_SERVER_PREFIX} \
    --os-disk-name jumpbox-${serverPrefix}-disk --image OpenLogic:CentOS:7.2:latest \
    --nsg NSG-ossdemo-utility  \
    --storage-sku Premium_LRS --size Standard_DS2_v2 \
    --vnet-name ossdemos-vnet --subnet ossdemo-utility-subnet \
    --admin-username ${JUMPBOX_ADMIN_NAME} \
    --ssh-key-value ~/.ssh/jumpbox_${serverPrefix}_id_rsa.pub "

    echo "..Calling creation command: ~/bin/az vm create ${azcreatecommand}"
    echo -e "${BOLD}...Creating Jumpbox server...${RESET}"
    ~/bin/az vm create ${azcreatecommand}
fi
echo ""
echo "----------------------------------------------"
read -p "$(echo -e -n "${INPUT}Please confirm the server is running in the Azure portal before continuing. ${RESET} \e[5m[press any key to continue]:${RESET}")"

#Download the GIT Repo for keys etc.
echo "--------------------------------------------"
echo -e "${BOLD}Configuring jumpbox server with ansible${RESET}"
echo ".Starting:"$(date)
cp ${SOURCEDIR}/ansible/jumpbox-server-configuration-template.yml ${SOURCEDIR}/ansible/jumpbox-server-configuration.yml -f
cp ${SOURCEDIR}/ansible/hosts-template ${SOURCEDIR}/ansible/hosts -f
sudo sed -i -e "s@JUMPBOXSERVER-REPLACE.eastus.cloudapp.azure.com@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com@g" ${SOURCEDIR}/ansible/hosts
sudo sed -i -e "s@VALUEOF_DEMO_ADMIN_USER@${JUMPBOX_ADMIN_NAME}@g" ${SOURCEDIR}/ansible/jumpbox-server-configuration.yml

echo ""
echo "---------------------------------------------"
echo "Configure demo template values file"
echo ".current pwd:" $(pwd) " current location of script:"${SOURCEDIR}
cp ${SOURCEDIR}/vm-assets/DemoEnvironmentValues-template ${SOURCEDIR}/vm-assets/DemoEnvironmentValues -f
sudo sed -i -e "s@JUMPBOX_SERVER_NAME=@JUMPBOX_SERVER_NAME=jumpbox-${serverPrefix}.eastus.cloudapp.azure.com@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues
sudo sed -i -e "s@DEMO_SERVER_PREFIX=@DEMO_SERVER_PREFIX=${serverPrefix}@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues
sudo sed -i -e "s@DEMO_STORAGE_ACCOUNT=@DEMO_STORAGE_ACCOUNT=${storagePrefix}storage@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues
sudo sed -i -e "s@DEMO_STORAGE_PREFIX=@DEMO_STORAGE_PREFIX=${storagePrefix}@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues
sudo sed -i -e "s@DEMO_ADMIN_USER=@DEMO_ADMIN_USER=${JUMPBOX_ADMIN_NAME}@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues

#Set the remote jumpbox passwords
echo "Resetting ${JUMPBOX_ADMIN_NAME} and root passwords based on script values."
echo "Starting:"$(date)
ssh -t -o BatchMode=yes -o StrictHostKeyChecking=no ${JUMPBOX_ADMIN_NAME}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com -i ~/.ssh/jumpbox_${serverPrefix}_id_rsa "echo '${JUMPBOX_ADMIN_NAME}:${JUMPBOX_ADMIN_PASSWORD}' | sudo chpasswd"
ssh -t -o BatchMode=yes -o StrictHostKeyChecking=no ${JUMPBOX_ADMIN_NAME}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com -i ~/.ssh/jumpbox_${serverPrefix}_id_rsa "echo 'root:${JUMPBOX_ADMIN_PASSWORD}' | sudo chpasswd"

#Copy the SSH private & public keys up to the jumpbox server
echo "Copying up the SSH Keys for demo purposes to the jumpbox ~/.ssh directories for ${JUMPBOX_ADMIN_NAME} user."
echo "Starting:"$(date)
scp ~/.ssh/jumpbox_${serverPrefix}_id_rsa ${JUMPBOX_ADMIN_NAME}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com:~/.ssh/id_rsa
scp ~/.ssh/jumpbox_${serverPrefix}_id_rsa.pub ${JUMPBOX_ADMIN_NAME}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com:~/.ssh/id_rsa.pub
ssh -t -o BatchMode=yes -o StrictHostKeyChecking=no ${serverAdminName}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com -i ~/.ssh/jumpbox_${serverPrefix}_id_rsa 'sudo chmod 600 ~/.ssh/id_rsa'

#mkdir for source on jumpbox server
echo "Copying the template values file to the jumpbox server in /source directory."
echo "Starting:"$(date)

ssh -t -o BatchMode=yes -o StrictHostKeyChecking=no ${serverAdminName}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com -i ~/.ssh/jumpbox_${serverPrefix}_id_rsa 'sudo mkdir /source'
ssh -t -o BatchMode=yes -o StrictHostKeyChecking=no ${serverAdminName}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com -i ~/.ssh/jumpbox_${serverPrefix}_id_rsa 'sudo chmod 777 -R /source'
scp ${SOURCEDIR}/vm-assets/DemoEnvironmentValues ${serverAdminName}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com:/source/DemoEnvironmentValues

echo ""
echo "Launch Microsoft or MAC RDP via --> mstsc and enter your jumpbox servername:jumpbox-${serverPrefix}.eastus.cloudapp.azure.com" 
echo "   or leverage the RDP file created in /source/JUMPBOX-SERVER.rdp"
sudo cp ${SOURCEDIR}/vm-assets/JUMPBOX-SERVER.rdp ${SOURCEDIR}/OSSDemo-jumpbox-server.rdp
sudo sed -i -e "s@VALUEOF_JUMPBOX_SERVER_NAME@jumpbox-${serverPrefix}@g" ${SOURCEDIR}/OSSDemo-jumpbox-server.rdp
sudo sed -i -e "s@VALUEOF_DEMO_ADMIN_USER@${serverAdminName}@g" ${SOURCEDIR}/OSSDemo-jumpbox-server.rdp

echo ""
ansiblecommand=" -i hosts jumpbox-server-configuration.yml --private-key ~/.ssh/jumpbox_${serverPrefix}_id_rsa"
echo ".Calling command: ansible-playbook ${ansiblecommand}"
#we need to run ansible-playbook in the same directory as the CFG file.  Go to that directory then back out...
cd ${SOURCEDIR}/ansible
    ansible-playbook ${ansiblecommand}
cd ..

echo "SSH is available via: ssh ${serverAdminName}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com -i ~/.ssh/jumpbox_${serverPrefix}_id_rsa "
echo ""
echo "Enjoy and please report any issues in the GitHub issues page or email GBBOSS@Microsoft.com..."
echo ""
echo "Finished:"$(date)