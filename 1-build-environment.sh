#!/bin/bash
echo "Welcome to the OSS Demo Jumpbox install process.  This script will:"
echo "    - Install git"
echo "    - Install Azure CLI if not present"
echo "    - Log in to Azure and create a Resource Group 'ossdemo-utility' and CENTOS VM"
echo ""
echo "Installation will require SU rights."
echo ""
echo "Installing git & ansible if they are missing."



#Check DISTRO
if [ -f /etc/redhat-release ]; then
  sudo yum update -y
  sudo yum -y install git
fi
if [ -f /etc/lsb-release ]; then
  gitinfo=$(dpkg-query -W -f='${Package} ${Status} \n' git | grep "git install ok installed")
  if [[ $gitinfo =~ "git install ok installed" ]]; then
     echo "   git installed - skipping"
  else  
     echo "   could not find git - installing...."
     sudo apt-get install git -y
  fi
  # sudo apt-get install software-properties-common -y
  # sudo apt-add-repository ppa:ansible/ansible -y
  # sudo apt-get update -y
  # sudo apt-get install ansible -y
  # sudo apt-get update && apt-get install -y libssl-dev libffi-dev python-dev
fi

echo ""
echo "Installing AZ command line tools if they are missing."
#Check to see if Azure is installed if not do it...
if [ -f ~/bin/az ]
  then
    echo "    AZ Client installed. Skipping install.."
  else
    curl -L https://aka.ms/InstallAzureCli | bash
    exec -l $SHELL
fi
clear
echo ""
echo "Logging in to Azure"
#Checking to see if we are logged into Azure
echo "    Checking if we are logged in to Azure."
#We need to redirect the output streams to stdout
azstatus=`az group list 2>&1` 
if [[ $azstatus =~ "Please run 'az login' to setup account." ]]; then
   echo "   We need to login to azure.."
   az login
else
   echo "    Logged in."
fi
read -p "    Change default subscription? [y/n]:" changesubscription
if [[ $changesubscription =~ "y" ]];then
    read -p "      New Subscription Name:" newsubscription
    az account set --subscription "$newsubscription"
else
    echo "    Using default existing subscription."
fi

echo ""
echo "Set values for creation of resource groups and jumpbox server"
# Check the validity of the name (no dashes, spaces, less than 8 char, no special chars etc..)
# Can we set a Enviro variable so if you want to rerun it is here and set by default?
echo "    Please enter your unique server prefix: (Jumpbox server will become:'utility-PREFIX-jumpbox')"
echo "      Note - values should be lowercase and less than 8 characters.')" 
read -p "Server Prefix:" serverPrefix
serverPrefix=${serverPrefix,,} 
echo ""


### JUMPBOX SERVER PASSWORD
echo ""
echo "Set initial password for jumpbox server:"
stty -echo
read jumpboxPassword
stty echo
echo ""

#Looking for jumpbox ssh key - if not found create one
echo "We are copying in a new private key.  If we find an existing id_rsa we will make a copy and cleanup after."
if [ -f ~/.ssh/ossdemo_id_rsa ]
  then
    echo "    Existing private key found.  Using this key ~/.ssh/ossdemo_id_rsa for jumpbox creation"
  else
    echo "    Creating new key for ssh in ~/.ssh/ossdemo_id_rsa"
    #Create key
    ssh-keygen -f ~/.ssh/ossdemo_id_rsa -N ""
    #Add this key to the ssh config file
    
fi
if grep -Fxq "Host jumpbox-${serverPrefix}.eastus.cloudapp.azure.com" ~/.ssh/config
then
    # Replace the server with the right private key
    sudo sed -i "s/*Host jumpbox-${serverPrefix}.eastus.cloudapp.azure.com*/Host jumpbox-${serverPrefix}.eastus.cloudapp.azure.com  IdentityFile ~/..ssh/ossdemo_id_rsa/g" ~/.ssh/config
else
    # Add this to the config file
    sudo echo "Host jumpbox-${serverPrefix}.eastus.cloudapp.azure.com  IdentityFile ~/..ssh/ossdemo_id_rsa" >> ~/.ssh/config
fi
sudo chmod 600 ~/.ssh/config
sudo chmod 600 ~/.ssh/oss*

# Check the validity of the name (no dashes, spaces, less than 8 char, no special chars etc..)"
# Can we set a Enviro variable so if you want to rerun it is here and set by default?
echo "    Please enter your unique storage prefix: (Storage Account will become: 'PREFIX-storage'')"
echo "      Note - values should be lowercase and less than 8 characters.')"
read -e -i "$serverPrefix" -p "Storage Prefix: " storagePrefix
storagePrefix=${storagePrefix,,}
echo ""

echo ""
read -p "Create resource group, and network rules?"  continuescript
if [[ $continuescript != "n" ]];then

#BUILD RESOURCE GROUPS
echo ""
echo "BUILDING RESOURCE GROUPS"
echo "--------------------------------------------"
echo 'create utility resource group'
az group create --name ossdemo-utility --location eastus

#BUILD NETWORKS SECURTIY GROUPS and RULES
echo ""
echo "BUILDING NETWORKS SECURTIY GROUPS and RULES"
echo "--------------------------------------------"
echo 'Network Security Group for utility Resource Group'
az network nsg create --resource-group ossdemo-utility --name NSG-ossdemo-utility --location eastus

echo 'Allow RDP inbound to Utility'
az network nsg rule create --resource-group ossdemo-utility \
     --nsg-name NSG-ossdemo-utility --name rdp-rule \
     --access Allow --protocol Tcp --direction Inbound --priority 100 \
     --source-address-prefix Internet \
     --source-port-range "*" --destination-address-prefix "*" \
     --destination-port-range 3389
 echo 'Allow SSH inbound to Utility'
 az network nsg rule create --resource-group ossdemo-utility \
     --nsg-name NSG-ossdemo-utility --name ssh-rule \
     --access Allow --protocol Tcp --direction Inbound --priority 110 \
     --source-address-prefix Internet \
     --source-port-range "*" --destination-address-prefix "*" \
     --destination-port-range 22
fi
echo ""
read -p "Create storage accounts and jumpbox server?"  continuescript
if [[ $continuescript != "n" ]];then

#BUILD STORAGE ACCOUNTS
echo ""
echo "BUILDING STORAGE ACCOUNTS"
echo "--------------------------------------------"
echo "Create Utility Storage account - you may need to change this in case there is a conflict"
echo "this is used in VM Create (Diagnostics storage) and Azure Registry"

az storage account create -l eastus -n ${storagePrefix}storage -g ossdemo-utility --sku Standard_LRS

#CREATE UTILITY JUMPBOX SERVER
echo ""
echo 'Creating CENTOS JUMPBOX utility machine for RDP and ssh'
echo 'Reading ssh key information from local ossdemo_id_rsa.pub file'
echo "--------------------------------------------"
sshpubkey=$(< ~/.ssh/ossdemo_id_rsa.pub)
az vm create -g ossdemo-utility -n jumpbox-${serverPrefix} \
        --public-ip-address-dns-name jumpbox-${serverPrefix} \
        --os-disk-name jumpbox-${serverPrefix}-disk \
        --image "OpenLogic:CentOS:7.2:latest" --os-type linux --nsg NSG-ossdemo-utility  --storage-sku Premium_LRS \
        --size Standard_DS1_v2 --admin-username GBBOSSDemo \
        --ssh-key-value "${sshpubkey}"
fi

#Download the GIT Repo for keys etc.
echo "--------------------------------------------"
echo "Downloading the Github repo for the connectivity keys and bits."
sudo mkdir /source
cd /source
sudo rm -rf /source/OSSonAzure
sudo git clone https://github.com/dansand71/OSSonAzure

# #Created Server - now SSH into the server
# echo "We are copying in a new private key.  If we find an existing id_rsa we will make a copy and cleanup after."
# if [ -f ~/.ssh/id_rsa ]
#   then
#     echo "    Existing private key found.  Making a copy for backup id_rsa_OSSDEMOBACKUP"
#     sudo mv ~/.ssh/id_rsa ~/.ssh/id_rsa_OSSDEMOBACKUP
# fi
# sudo cp /source/OSSonAzure/ssh-keys/id_rsa ~/.ssh/id_rsa
# sudo chmod 600 ~/.ssh/id_rsa
# sudo chown $USER ~/.ssh/id_rsa

echo "--------------------------------------------"
echo "Configure jumpbox server with ansible"
sudo sed -i -e "s/JUMPBOXSERVER-REPLACE/jumpbox-${serverPrefix}.eastus.cloudapp.azure.com/g" /source/OSSonAzure/ansible/hosts
ansible-playbook -i /source/OSSonAzure/ansible/hosts /source/OSSonAzure/ansible/jumpbox-server-configuration.yml

#Set the remote jumpbox passwords
ssh GBBOSSDemo@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com 'echo "GBBOSSDemo:${jumpboxPassword}" | sudo chpasswd'
ssh GBBOSSDemo@jumpbox-${serverPrefix}.eastus.cloudapp.azure.com 'echo "root:${jumpboxPassword}" | sudo chpasswd'

# echo ""
# echo "Cleaning up the RSA Keys"
# #CLEANUP & Finish
# if [ -f ~/.ssh/id_rsa_OSSDEMOBACKUP ]
#   then
#     echo "    Restoring previous SSH private key."
#     sudo rm ~/.ssh/id_rsa
#     sudo mv ~/.ssh/id_rsa_OSSDEMOBACKUP ~/.ssh/id_rsa
# fi
# echo ""

echo ""
echo "Launch Microsoft RDP via WindowsKey --> mstsc and enter your jumpbox servername:jumpbox-${serverPrefix}.eastus.cloudapp.azure.com" 
echo "Demos will be found under \source\OSSonAzure"
echo ""