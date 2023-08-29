#!/bin/bash

# 0. Gather information from user 
    # SOAR FQDNs or IPs - Identify primary and secondary/dr
    # Certs for both SOAR instances 
    # Resadmin Password
    # Vault password
    # Path to Optional Packages repo
# 1. Test communication to each appliance and check SOAR versions match 
    # Ensure primary system has a license 
# 2. Install the resilient-dr package
    # Ensure resilient-dr version is the same
# 3. Run the optional packages repo file and install necessary packages
    # Ensure lsyncd is the same 
# 4. Setup SSH keys on both machines for the resfilesync user
# 5. Setup ssh_vault.yaml files on both machines
    # Encrypt the vaults 
# 6. Manually installing postgres SSL certificates
# 7. Create Ansible inventory files on each machine 
# 8. Create Ansible vault files 
    # Encrypt the vaults 
# 9. Clean up 
# 10. Show results to users 

#---------------------------------------------------------------------------------------------#

echo "This script will setup the SOAR appliance's Disaster Recovery system"
echo "Run this script on the Primary SOAR Appliance" 
echo "Make sure the Prerequisites are complete before running the setup" 
echo "Prerequisite Documentation: https://www.ibm.com/docs/en/sqsp/49?topic=overview-prerequisites"
echo "Let's get started!"
sleep 2
# 0. Gather information from user 

echo "Let's gather some information about your SOAR appliances" 
echo -en "\n"

## SOAR appliance IPs/FQDN
PRIMARY_SOAR_IP=$(hostname --all-ip-addresses | awk '{ print $1 }')
PRIMARY_SOAR_HOSTNAME=$(hostname)
echo "Primary SOAR IP is $PRIMARY_SOAR_IP"
read -p "Is this the proper IP Address for the Primary SOAR appliance? (y/n) " yn

case $yn in 
	[yY] ) echo ;
		:;;
	[nN] ) read -p 'Input Primary SOAR IP: ' PRIMARY_SOAR_IP;
		:;;
	* ) echo invalid response;;
esac

read -p 'Input Secondary/DR SOAR IP: ' SECONDARY_SOAR_IP

echo -en "\n"
echo "This script will use the resadmin account to log into the SOAR systems to make the necessary changes" 
echo "Both systems are required to have the same resadmin password for the Disaster Recovery System to work"
echo "If both systems do not have the same resadmin password, cancel this script and update the passwords" 
read -sp "resadmin password: " RESADMIN_PASS

echo -en "\n" 
echo -en "\n" 
echo "To ensure the configuration files are secured, they are ran through ansible-vault to encrypt them" 
echo "Please provide a password to secure these files with, the same password must be used on all ansible-vault files" 
read -sp "Vault password: " VAULT_PASS

echo -en "\n"
echo -en "\n"
echo "Resilient-dr will setup a Postgres replication user. Please specify the password this user account should use" 
echo "Do not use the following characters in the password: \" ' ) ( ; ."
read -sp "Postgres Replication user password: " POSTGRES_REP_PASSWORD

echo -en "\n" 
echo -en "\n" 
echo "Postgres replication is secured through an SSL connection" 
echo "To set this up, certificates are required for both systems" 
echo "Postgres for SSL requires a server.crt, server.key, and root.crt" 
echo "Place all of the certificates in two folders." 
read -p "Path to primary certificate folder (example: /home/resadmin/certs/primary): " PRIMARY_CERTS
read -p "Path to DR certificate folder (example: /home/resadmin/certs/dr): " SECONDARY_CERTS 

echo -en "\n" 
echo "The Disaster Recovery System requires packages that are in the soar-optional-packages-repo" 
echo "Download the .run file onto the Primary appliance. Provide the directory the .run file is in." 
read -p "Directory to soar-optional-packages-repo.run (example: /home/resadmin/): " OPTIONAL_PACKAGES_PATH

echo -en "\n" 
echo "Thank you for the information!" 
echo "Now configuring the Disaster Recovery System" 
sleep 1

# 1. Test communication to each appliance and check SOAR versions match 

echo -en "\n" 
echo "Testing communication to the SOAR appliances"

if ping -c1 -W1 -q $PRIMARY_SOAR_IP &> /dev/null
then 
    echo "Communication successful with Primary SOAR" 
else
    echo "Unable to reach DR SOAR. Check your network connections." 
    exit
fi

if ping -c1 -W1 -q $SECONDARY_SOAR_IP &> /dev/null
then 
    echo "Communication successful with DR SOAR" 
else
    echo "Unable to reach DR SOAR. Check your network connections." 
    exit
fi

# Ensure primary system has a license 
echo -en "\n" 
echo "Checking for SOAR license" 
if sudo test -f "/crypt/license/license.key"; then
    echo "License found" 
else
    echo "License not found on Primary SOAR. License required to continue." 
    exit
fi

# Check SOAR versions match 
echo -en "\n" 
echo "Checking SOAR versions" 
PRIMARY_SOAR_VERSION=$(sudo resutil -v | awk '{ print $NF }' | tr -d '\n\t\r ')
SECONDARY_SOAR_VERSION=$(sudo -u resadmin ssh -o StrictHostKeyChecking=no -q -t resadmin@$SECONDARY_SOAR_IP "echo $RESADMIN_PASS | sudo -S resutil -v" | awk '{ print $NF }' | tr -d '\n\t\r ')

if [ "$PRIMARY_SOAR_VERSION" == "$SECONDARY_SOAR_VERSION" ]; then
    echo "Both SOAR appliances are running the same version"
else
    echo "The SOAR appliances are not running the same version"
    echo "The appliances must be the same before continuing" 
    echo "Primary SOAR Version: $PRIMARY_SOAR_VERSION"
    echo "DR SOAR Version: $SECONDARY_SOAR_VERSION"
    exit
fi

# 2. Install the resilient-dr package

sleep 2
echo -en "\n" 
echo "Installing the Resilient-dr package on both appliances"

## Install on primary appliance 
yum install -y -q resilient-dr 1>/dev/null
PRIMARY_DR_VERSION=$(repoquery --qf '%{version}' resilient-dr)
echo "Installed on primary, running version $PRIMARY_DR_VERSION" 

## Install on secondary appliance 
SECONDARY_DR_INSTALL=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "echo -e '$RESADMIN_PASS\n' | sudo -S yum install -y -q resilient-dr 1>/dev/null")
SECONDARY_DR_VERSION=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "echo -e '$RESADMIN_PASS\n' | sudo -S repoquery --qf '%{version}' resilient-dr" | awk '{ print $NF }' | tr -d '\n\t\r')
echo "installed on secondary, running version $SECONDARY_DR_VERSION" 

# 3. Run the optional packages repo file and install necessary packages
sleep 2
echo -en "\n"
echo "Installing optional package repo and necessary packages" 

# Install Optional package 
OPTIONAL_PACKAGES_PATH_FULL=$(find $OPTIONAL_PACKAGES_PATH -name "soar-optional-packages*.run")
OPTIONAL_PACKAGE=$(basename $OPTIONAL_PACKAGES_PATH_FULL)

## Install on primary appliance 
$OPTIONAL_PACKAGES_PATH_FULL > /dev/null 2>&1

## Transfer and execute on secondary appliance 
sudo -u resadmin scp -q -o LogLevel=QUIET $OPTIONAL_PACKAGES_PATH_FULL resadmin@$SECONDARY_SOAR_IP:/home/resadmin
SECONDARY_OPTIONAL_INSTALL=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "echo -e '$RESADMIN_PASS\n' | sudo -S /home/resadmin/$OPTIONAL_PACKAGE 1>/dev/null")

echo "Optional packages installed on appliances" 

# Install lsyncd 

## Install on primary appliance 
yum install -y -q lsyncd 1>/dev/null 

## Install on secondary appliance 
SECONDARY_DR_INSTALL=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "echo -e '$RESADMIN_PASS\n' | sudo -S yum install -y -q lsyncd 1>/dev/null")

echo "lsyncd installed on appliances" 

# 4. Setup SSH keys on both machines for the resfilesync user
sleep 2 
echo -en "\n"
echo "Setting up resfilesync user on appliances" 

## Setup resfilesync key on primary appliance
sudo -u resadmin ssh-keygen -q -t rsa -b 4096 -C "resfilesync@res-dr" -f /usr/share/resilient-dr/ansible/files/id_rsa -N "" <<<y >/dev/null 2>&1
if [ -f /usr/share/resilient-dr/ansible/files/id_rsa ]; then 
    echo "resfilesync keys set on Primary" 
else 
    echo "resfilesync key not set on primary"
fi 

## Setup resfilesync key on secondary appliance
SECONDARY_RESFILESYNC_STATUS=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "ssh-keygen -t rsa -b 4096 -C "resfilesync@res-dr" -f /usr/share/resilient-dr/ansible/files/id_rsa -N '' <<<y >/dev/null 2>&1 && test -e /usr/share/resilient-dr/ansible/files/id_rsa && echo "resfilesync keys set on secondary" || echo "resfilesync key not set on secondary"")
echo $SECONDARY_RESFILESYNC_STATUS

# 5. Setup ssh_vault.yml files on both machines
sleep 2
echo -en "\n"
echo "Configuring ssh_vault.yml files" 

# Primary Appliance 
## Copy ssh_vault from template to files directory
sudo -u resadmin cp /usr/share/resilient-dr/ansible/templates/ssh_vault.template.yml /usr/share/resilient-dr/ansible/files/ssh_vault.yml

## Update ssh_vault with resfilesync keys 
### Insert keys into file
sed -i -e '/<INSERT_PRIVATE_KEY_HERE>/{r /usr/share/resilient-dr/ansible/files/id_rsa' -e 'd}' /usr/share/resilient-dr/ansible/files/ssh_vault.yml
sed -i -e '/<INSERT_PUBLIC_KEY_HERE>/{r /usr/share/resilient-dr/ansible/files/id_rsa.pub' -e 'd}' /usr/share/resilient-dr/ansible/files/ssh_vault.yml

### Update spacing 
sed -i '9,59s/^/        /' /usr/share/resilient-dr/ansible/files/ssh_vault.yml
sed -i '65s/^/        /' /usr/share/resilient-dr/ansible/files/ssh_vault.yml

### Ansible-Vault encrypt ssh_vault yaml file 
echo $VAULT_PASS > /home/resadmin/.vault_pass
chmod 600 /home/resadmin/.vault_pass && chown resadmin:resadmin /home/resadmin/.vault_pass
source /opt/ansible-venv/python/ansible-python-env-latest/bin/activate && sudo -u resadmin ansible-vault encrypt /usr/share/resilient-dr/ansible/files/ssh_vault.yml --vault-password-file /home/resadmin/.vault_pass
deactivate

echo "ssh_vault.yml configured and encrypted on primary appliance" 

# Secondary Appliance
## Line 1 - Copy ssh_vault from template to files directory
## Line 2-3 - Update ssh_vault with resfilesync keys 
## Line 4-5 - Update spacing 
sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP << EOF
 cp /usr/share/resilient-dr/ansible/templates/ssh_vault.template.yml /usr/share/resilient-dr/ansible/files/ssh_vault.yml
 sed -i -e '/<INSERT_PRIVATE_KEY_HERE>/{r /usr/share/resilient-dr/ansible/files/id_rsa' -e 'd}' /usr/share/resilient-dr/ansible/files/ssh_vault.yml
 sed -i -e '/<INSERT_PUBLIC_KEY_HERE>/{r /usr/share/resilient-dr/ansible/files/id_rsa.pub' -e 'd}' /usr/share/resilient-dr/ansible/files/ssh_vault.yml
 sed -i '9,59s/^/        /' /usr/share/resilient-dr/ansible/files/ssh_vault.yml
 sed -i '65s/^/        /' /usr/share/resilient-dr/ansible/files/ssh_vault.yml
EOF

## Encrypt the vault
sudo -u resadmin scp -q -o LogLevel=QUIET /home/resadmin/.vault_pass resadmin@$SECONDARY_SOAR_IP:/home/resadmin
sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "chmod 600 /home/resadmin/.vault_pass && source /opt/ansible-venv/python/ansible-python-env-latest/bin/activate && ansible-vault encrypt /usr/share/resilient-dr/ansible/files/ssh_vault.yml --vault-password-file /home/resadmin/.vault_pass"

echo "ssh_vault.yml configured and encrypted on secondary appliance" 

# 6. Manually installing postgres SSL certificates
sleep 2
echo -en "\n"
echo "Configuring postgres SSL files" 

## Setting up primary appliance 
### Create /crypt/postgresql and move server.crt and server.key into it
install -d -m 750 -g postgres -o postgres /crypt/postgresql
cp $PRIMARY_CERTS/server.crt /crypt/postgresql/server.crt && chown postgres:postgres /crypt/postgresql/server.crt && chmod 0644 /crypt/postgresql/server.crt
cp $PRIMARY_CERTS/server.key /crypt/postgresql/server.key && chown postgres:postgres /crypt/postgresql/server.key && chmod 0600 /crypt/postgresql/server.key

### Create .postgresql directoy on secondary appliance 
SECONDARY_DIRECTORY_CREATE=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "echo -e '$RESADMIN_PASS\n' | sudo -S install -d -m 731 -g postgres -o postgres /var/lib/pgsql/.postgresql")

### Move root.crt to secondary appliance 
sudo -u resadmin scp -q -o LogLevel=QUIET $PRIMARY_CERTS/root.crt resadmin@$SECONDARY_SOAR_IP:/home/resadmin/root.crt
SECONDARY_DIRECTORY_MOVE=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "echo -e '$RESADMIN_PASS\n' | sudo -S cp /home/resadmin/root.crt /var/lib/pgsql/.postgresql/root.crt && sudo -S chown postgres:postgres /var/lib/pgsql/.postgresql/root.crt && sudo -S chmod 0644 /var/lib/pgsql/.postgresql/root.crt && rm /home/resadmin/root.crt")

## Setting up secondary appliance 
### Create /crypt/postgresql and move server.crt and server.key into it
SECONDARY_DIRECTORY_CREATE=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "echo -e '$RESADMIN_PASS\n' | sudo -S install -d -m 750 -g postgres -o postgres /crypt/postgresql")
sudo -u resadmin scp -q -o LogLevel=QUIET $SECONDARY_CERTS/* resadmin@$SECONDARY_SOAR_IP:/home/resadmin 
SECONDARY_DIRECTORY_CREATE=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "echo -e '$RESADMIN_PASS\n' | sudo -S cp /home/resadmin/server.crt /crypt/postgresql/server.crt && sudo -S chown postgres:postgres /crypt/postgresql/server.crt && sudo -S chmod 0644 /crypt/postgresql/server.crt")
SECONDARY_DIRECTORY_CREATE=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "echo -e '$RESADMIN_PASS\n' | sudo -S cp /home/resadmin/server.key /crypt/postgresql/server.key && sudo -S chown postgres:postgres /crypt/postgresql/server.key && sudo -S chmod 0600 /crypt/postgresql/server.key")
SECONDARY_DIRECTORY_CREATE=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "rm /home/resadmin/server.crt /home/resadmin/server.key /home/resadmin/root.crt")

### Create .postgresql directoy on primary appliance 
install -d -m 731 -g postgres -o postgres /var/lib/pgsql/.postgresql

### Move secondary root.crt in primary appliance and set permissions
cp $SECONDARY_CERTS/root.crt /var/lib/pgsql/.postgresql/root.crt 
chown postgres:postgres /var/lib/pgsql/.postgresql/root.crt 
chmod 0644 /var/lib/pgsql/.postgresql/root.crt

echo "Certificates have been installed" 

# 7. Create Ansible inventory files on each machine 
sleep 2
echo -en "\n"
echo "Configuring Ansible inventory files" 

## Get secondary appliance hostname
SECONDARY_SOAR_HOSTNAME=$(sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "hostname")
SECONDARY_SOAR_HOSTNAME=$(echo $SECONDARY_SOAR_HOSTNAME | tr -d '\n\t\r ')

## Primary Appliance inventory file 
## Copy template
sudo -u resadmin cp /usr/share/resilient-dr/ansible/templates/inventory.template.yml /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_a.yml

## Modify inventory file
sed -i "9s/<REPLACE_ME_WITH_AN_IP_OR_FQDN>/$PRIMARY_SOAR_IP/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_a.yml #master_host
sed -i "17s/<REPLACE_ME_WITH_AN_IP_OR_FQDN>/$SECONDARY_SOAR_IP/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_a.yml #receiver_host
sed -i "26s/<REPLACE_ME_WITH_AN_FQDN>/$PRIMARY_SOAR_HOSTNAME/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_a.yml #inv_vars_master_host
sed -i "27s/<REPLACE_ME_WITH_AN_FQDN>/$SECONDARY_SOAR_HOSTNAME/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_a.yml #inv_vars_receiver_host
sed -i "32s/<REPLACE_ME_WITH_AN_IP_AND_NETMASK>/$SECONDARY_SOAR_IP\/32/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_a.yml #inv_vars_master_host_firewalld_range

## Move to secondary 
sudo -u resadmin scp -q -o LogLevel=QUIET /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_a.yml resadmin@$SECONDARY_SOAR_IP:/usr/share/resilient-dr/ansible/inventories/

## Secondary appliance inventory file 
## Copy template
sudo -u resadmin cp /usr/share/resilient-dr/ansible/templates/inventory.template.yml /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_b.yml

## Modify inventory file
sed -i "9s/<REPLACE_ME_WITH_AN_IP_OR_FQDN>/$SECONDARY_SOAR_IP/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_b.yml #master_host
sed -i "17s/<REPLACE_ME_WITH_AN_IP_OR_FQDN>/$PRIMARY_SOAR_IP/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_b.yml #receiver_host
sed -i "26s/<REPLACE_ME_WITH_AN_FQDN>/$SECONDARY_SOAR_HOSTNAME/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_b.yml #inv_vars_master_host
sed -i "27s/<REPLACE_ME_WITH_AN_FQDN>/$PRIMARY_SOAR_HOSTNAME/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_b.yml #inv_vars_receiver_host
sed -i "32s/<REPLACE_ME_WITH_AN_IP_AND_NETMASK>/$PRIMARY_SOAR_IP\/32/" /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_b.yml #inv_vars_master_host_firewalld_range

## Move to secondary 
sudo -u resadmin scp -q -o LogLevel=QUIET /usr/share/resilient-dr/ansible/inventories/resilient_hosts_primary_machine_b.yml resadmin@$SECONDARY_SOAR_IP:/usr/share/resilient-dr/ansible/inventories/

echo "Inventory files have been created" 

# 8. Create Ansible vault files 
sleep 2
echo -en "\n"
echo "Configuring Ansible vault files" 

## Copy template
sudo -u resadmin cp /usr/share/resilient-dr/ansible/templates/vault.template /usr/share/resilient-dr/ansible/group_vars/all/vault

sed -i "37s/verify-full/require/" /usr/share/resilient-dr/ansible/group_vars/all/vault # vault_postgres_ssl_security_level
sed -i "49s/<REPLACE_WITH_REP_DB_PASSWORD>/$POSTGRES_REP_PASSWORD/" /usr/share/resilient-dr/ansible/group_vars/all/vault # vault_postgres_ssl_security_level

## Encrypt the vault
source /opt/ansible-venv/python/ansible-python-env-latest/bin/activate && sudo -u resadmin ansible-vault encrypt /usr/share/resilient-dr/ansible/group_vars/all/vault --vault-password-file /home/resadmin/.vault_pass
deactivate

## Copy to secondary appliance
sudo -u resadmin scp -q -o LogLevel=QUIET /usr/share/resilient-dr/ansible/group_vars/all/vault resadmin@$SECONDARY_SOAR_IP:/usr/share/resilient-dr/ansible/group_vars/all/

# 9. Clean up 

## Delete Ansible-Vault encrypt ssh_vault yaml file 
rm /home/resadmin/.vault_pass
sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "rm /home/resadmin/.vault_pass"

# # 10. Show results to users 
sleep 2
echo -en "\n"
echo "Resilient-dr has been configured!" 

echo -en "\n"
echo "The configuration files should now be setup with the proper ownership and permissions set"
echo "Ensure your systems look similiar to this example"
echo -en "\n"
echo "group_vars/all:
rw-r----. 1 resadmin co3 vars
rw------. 1 resadmin resadmin vault

files/
rw------. 1 resadmin resadmin ssh_vault.yml
rw------. 1 resadmin resadmin <ssl_certs_vault_a.yml>
rw------. 1 resadmin resadmin <ssl_certs_vault_b.yml>

inventories/
rw-r----. 1 resadmin resadmin <resilient_hosts_master_machine_a.yml>
rw-r----. 1 resadmin resadmin <resilient_hosts_master_machine_b.yml>"

echo -en "\n" 
echo "Primary Appliance files"
echo "group_vars/all:" 
ls -l /usr/share/resilient-dr/ansible/group_vars/all

echo -en "\n"
echo "files:"
ls -l /usr/share/resilient-dr/ansible/files

echo -en "\n"
echo "inventories:"
ls -l /usr/share/resilient-dr/ansible/inventories

echo -en "\n"

echo "Secondary Appliance files"
echo "group_vars/all:" 
sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "ls -l /usr/share/resilient-dr/ansible/group_vars/all"

echo -en "\n"
echo "files:"
sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "ls -l /usr/share/resilient-dr/ansible/files"

echo -en "\n"
echo "inventories:"
sudo -u resadmin ssh -q -t resadmin@$SECONDARY_SOAR_IP "ls -l /usr/share/resilient-dr/ansible/inventories"