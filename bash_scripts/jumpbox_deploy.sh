#!/bin/bash

### JUMPBOX SERVER PASSWORD
while true
do
  read -s -p "$(echo -e -n "${INPUT}.New Admin Password for Jumpbox:${RESET}")" jumpboxPassword
  echo ""
  read -s -p "$(echo -e -n "${INPUT}.Re-enter to verify:${RESET}")" jumpboxPassword2
  
  if [ $jumpboxPassword = $jumpboxPassword2 ]
  then
     break 2
  else
     echo -e ".${RED}Passwords do not match.  Please retry. ${RESET}"
  fi
done

    #stty -echo
    #    read -s jumpboxPassword
    #stty echo

# Check the validity of the name (no dashes, spaces, less than 8 char, no special chars etc..)"
# Can we set a Enviro variable so if you want to rerun it is here and set by default?
echo ".Please enter your unique storage prefix: (Storage Account will become: 'PREFIX-storage'')"
echo "      (Note - values should be lowercase and less than 8 characters.)"
read -p "$(echo -e -n "${INPUT}.Storage Prefix? (default: ${serverPrefix}demostorage):"${RESET})" storagePrefix
[ -z "${storagePrefix}" ] && storagePrefix=${serverPrefix}
# This requires a newer version of BASH not avialble in MAC OS - storagePrefix=${storagePrefix,,} 
storagePrefix=$(echo "${storagePrefix}" | tr '[:upper:]' '[:lower:]')


echo ""
echo -e "${BOLD}Creation of Resource Group...${RESET}"
read -p "$(echo -e -n "${INPUT}Deploy Template to create resource group, and network rules? [Y/n]:"${RESET})" continuescript
if [[ $continuescript != "n" ]]; then
    #Make a copy of the template file
    cp ${SOURCEDIR}/environment/ossdemo-utility-template.json ${SOURCEDIR}/environment/ossdemo-utility.json -f
    #MODIFY line in JSON TEMPLATES
    sudo sed -i -e "s@VALUEOF-UNIQUE-SERVER-PREFIX@${serverPrefix}@g" ${SOURCEDIR}/environment/ossdemo-utility.json
    sudo sed -i -e "s@VALUEOF-UNIQUE-STORAGE-PREFIX@${storagePrefix}@g" ${SOURCEDIR}/environment/ossdemo-utility.json

    #BUILD RESOURCE GROUPS
    echo ".BUILDING RESOURCE GROUPS"
    echo "..Starting:"$(date)
    echo '..create utility resource group'
    ~/bin/az group create --name ossdemo-utility --location eastus

    #APPLY TEMPLATE
    echo ".APPLY JSON Template"
    echo "..Starting:"$(date)
    echo '..Applying Network Security Group for utility Resource Group'
    ~/bin/az group deployment create --resource-group ossdemo-utility --name InitialDeployment --template-file ${SOURCEDIR}/environment/ossdemo-utility.json

fi

echo ""
echo -e "${BOLD}Creation of Jumpbox server...${RESET}"
read -p "$(echo -e -n "${INPUT}Create jumpbox server? [Y/n]:"${RESET})" continuescript
if [[ $continuescript != "n" ]]; then
    #Looking for jumpbox ssh key - if not found create one
    echo ".We are creating a new VM with SSH enabled.  Looking for an existing key or creating a new one."
    if [ -f ~/.ssh/jumpbox_${serverPrefix}_id_rsa ]
    then
        echo "..Existing private key found.  Using this key ~/.ssh/jumpbox_${serverPrefix}_id_rsa for jumpbox creation"
    else
        echo "..Creating new key for ssh in ~/.ssh/jumpbox_${serverPrefix}_id_rsa"
        #Create key
        ssh-keygen -f ~/.ssh/jumpbox_${serverPrefix}_id_rsa -N "" -q
        #Add this key to the ssh config file 
    fi
    if grep -Fxq "Host jumpbox-${serverPrefix}.eastus.cloudapp.azure.com" ~/.ssh/config
    then
        # Replace the server with the right private key
        # BUG BUG - we need to actually replace the next three lines with new values
        # sed -i "s@*Host jumpbox-${serverPrefix}.eastus.cloudapp.azure.com*@Host=jumpbox-${serverPrefix}.eastus.cloudapp.azure.com IdentityFile=~/.ssh/jumpbox_${serverPrefix}_id_rsa User=${serverAdminName}@g" ~/.ssh/config
        echo "..We found an entry in ~/.ssh/config for this server - do not recreate."
    else
        # Add this to the config file
        echo -e "Host=jumpbox-${serverPrefix}.eastus.cloudapp.azure.com\nIdentityFile=~/.ssh/jumpbox_${serverPrefix}_id_rsa\nUser=${serverAdminName}" >> ~/.ssh/config
    fi

    sudo chmod 600 ~/.ssh/config
    sudo chmod 600 ~/.ssh/jumpbox*
    sshpubkey=$(< ~/.ssh/jumpbox_${serverPrefix}_id_rsa.pub)
    
    #Delete the host name in case it already exists
    ssh-keygen -R "jumpbox-${serverPrefix}.eastus.cloudapp.azure.com"

    #CREATE UTILITY JUMPBOX SERVER
    echo ""
    echo "Creating CENTOS JUMPBOX utility machine for RDP and ssh"
    echo ".Starting:"$(date)
    echo ".Reading ssh key information from local jumpbox_${serverPrefix}_id_rsa file"
    echo ".--------------------------------------------"
    azcreatecommand="-g ossdemo-utility -n jumpbox-${serverPrefix} --public-ip-address-dns-name jumpbox-${serverPrefix} \
    --os-disk-name jumpbox-${serverPrefix}-disk --image OpenLogic:CentOS:7.2:latest \
    --nsg NSG-ossdemo-utility  \
    --storage-sku Premium_LRS --size Standard_DS2_v2 \
    --vnet-name ossdemos-vnet --subnet ossdemo-utility-subnet \
    --admin-username ${serverAdminName} \
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
sudo sed -i -e "s@VALUEOF_DEMO_ADMIN_USER@${serverAdminName}@g" ${SOURCEDIR}/ansible/jumpbox-server-configuration.yml

echo ""
echo "---------------------------------------------"
echo "Configure demo template values file"
echo ".current pwd:" $(pwd) " current location of script:"${SOURCEDIR}
cp ${SOURCEDIR}/vm-assets/DemoEnvironmentValues-template ${SOURCEDIR}/vm-assets/DemoEnvironmentValues -f
sudo sed -i -e "s@JUMPBOX_SERVER_NAME=@JUMPBOX_SERVER_NAME=jumpbox-${serverPrefix}.eastus.cloudapp.azure.com@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues
sudo sed -i -e "s@DEMO_SERVER_PREFIX=@DEMO_SERVER_PREFIX=${serverPrefix}@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues
sudo sed -i -e "s@DEMO_STORAGE_ACCOUNT=@DEMO_STORAGE_ACCOUNT=${storagePrefix}storage@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues
sudo sed -i -e "s@DEMO_STORAGE_PREFIX=@DEMO_STORAGE_PREFIX=${storagePrefix}@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues
sudo sed -i -e "s@DEMO_ADMIN_USER=@DEMO_ADMIN_USER=${serverAdminName}@g" ${SOURCEDIR}/vm-assets/DemoEnvironmentValues

#Set the remote jumpbox passwords
echo "Resetting ${serverAdminName} and root passwords based on script values."
echo "Starting:"$(date)
ssh -t -o BatchMode=yes -o StrictHostKeyChecking=no ${serverAdminName}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com -i ~/.ssh/jumpbox_${serverPrefix}_id_rsa "echo '${serverAdminName}:${jumpboxPassword}' | sudo chpasswd"
ssh -t -o BatchMode=yes -o StrictHostKeyChecking=no ${serverAdminName}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com -i ~/.ssh/jumpbox_${serverPrefix}_id_rsa "echo 'root:${jumpboxPassword}' | sudo chpasswd"

#Copy the SSH private & public keys up to the jumpbox server
echo "Copying up the SSH Keys for demo purposes to the jumpbox ~/.ssh directories for ${serverAdminName} user."
echo "Starting:"$(date)
scp ~/.ssh/jumpbox_${serverPrefix}_id_rsa ${serverAdminName}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com:~/.ssh/id_rsa
scp ~/.ssh/jumpbox_${serverPrefix}_id_rsa.pub ${serverAdminName}@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com:~/.ssh/id_rsa.pub
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