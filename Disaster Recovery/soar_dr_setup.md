The script was developed to be ran from the primary appliance.

Ensure you have all of the prerequisites on the primary appliance before starting the script. 

## Prerequisites per [IBM docs](https://www.ibm.com/docs/en/sqsp/49?topic=overview-prerequisites)
- IP address of secondary/DR appliance 
- Resadmin password (same on both appliances)
- Vault password 
- Postgres Replication password
- Postgres for SSL certificates 
  - Must be named server.crt, server.key, and root.crt
  - Place the certificates in two folders, one for each appliance.
- SOAR Optional packages run file must be on the primary appliance. 
- SSH keys configured on both appliances 

#### The SOAR DR setup script will perform the following steps:

1. Gather information from user through prompts
    - SOAR FQDNs or IPs - Identify primary and secondary/dr
    - Resadmin Password
    - Vault password
    - Postgres Replication password
    - Certs for both SOAR instances 
    - Path to Optional Packages repo
2. Test communication to each appliance and check SOAR versions match 
    - Ensure primary system has a license 
3. Install the resilient-dr package
    - Ensure resilient-dr version is the same
4. Run the optional packages repo file and install necessary packages
    - Ensure lsyncd is the same 
5. Setup SSH keys on both machines for the resfilesync user
6. Setup ssh_vault.yaml files on both machines
    - Encrypt the vaults 
7. Manually installing postgres SSL certificates
8. Create Ansible inventory files on each machine 
9. Create Ansible vault files 
    - Encrypt the vaults 
10. Clean up 
11. Show results to users 

## How to run 
The script will prompt the user for credentials and paths. No flags are need to start the script. It does require sudo/root permissions to run. 
```
sudo ./soar_dr_setup.sh
```

