#!/bin/bash
# Load .env variables
export $(egrep -v '^#' .env | xargs)

# Start Vault and MySQL containers
docker-compose up

## Prepare MySQL Demo database
# We will be executin mysqlc from inside the docker container
# Import world demo database from MySQL site (download it first from https://dev.mysql.com/doc/index-other.html )
docker exec -it mysql-server mysql -u${MYSQL_ROOT_USERNAME} -p${MYSQL_ROOT_PASSWORD} -h 127.0.0.1
SOURCE world.sql
show databases;
use world
select * from city;

### Start Vault demo ####
## Install Vault
# Install vault using apt-get
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault

# Download vault binary from hashicorp site - Review version if needed at https://www.vaultproject.io/downloads
wget https://releases.hashicorp.com/vault/1.7.1/vault_1.7.1_linux_amd64.zip
unzip vault_1.7.1_linux_amd64.zip
mv vault /usr/local/bin/

## Enable vault audit to stdout
vault audit enable file file_path=stdout

## Database engine demo
# Enable database engine
vault secrets enable database

vault write database/config/app-database \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(mysql:3306)/" \
    allowed_roles=app-user,app-admin,app-backend username=${MYSQL_ROOT_USERNAME} password=${MYSQL_ROOT_PASSWORD}

vault write database/roles/app-user \
    db_name=app-database \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON world.* TO '{{name}}'@'%';" \
    default_ttl="1m" \
    max_ttl="30m"

vault write database/roles/app-admin \
    db_name=app-database \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL PRIVILEGES ON *.* TO '{{name}}'@'%';" \
    default_ttl="1h" \
    max_ttl="4h"

vault write database/roles/app-backend \
    db_name=app-database \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT,INSERT,DELETE,UPDATE ON world.* TO '{{name}}'@'%';" \
    default_ttl="24h" \
    max_ttl="336h"

# Write Vault Policies
vault policy write app-admin policies/app-admin.hcl

vault policy write app-user policies/app-user.hcl 

vault policy write app-backend policies/app-backend.hcl

# Generate token with app-admin policy
vault token create -policy app-admin

# In another terminal session login to vault with new token
    vault token lookup

    vault read database/creds/app-admin


# Check mysql for new user created
docker exec -it mysql-server mysql -u${MYSQL_ROOT_USERNAME} -p${MYSQL_ROOT_PASSWORD} -h 127.0.0.1

    select user from mysql.user;

#Login with backend credentials
vault token create -policy app-backend

# Get database credential using Curl
curl -s --header "X-Vault-Token: s.f9jKzVuEJ1NJhpdmXl0gz8SC" http://127.0.0.1:8200/v1/database/creds/app-backend | jq

# Get database credential using vault client
vault read database/creds/app-backend

#Login to MySQL with newly created credentials
docker exec -it mysql-server mysql -u<backend-username> -p<backend-password> -h 127.0.0.1
    show grants;
    use world;
    select * from city;
    delete from city where Name = 'Rafah';
    select * from city;

# Revoke credential
vault lease revoke -prefix database/

# Create token for user
vault token create -policy app-user

vault read database/creds/app-user

## Vault response wrap demo
# Create new KV entry in dev folder
vault kv put secret/dev username="webapp" password="my-long-password"

# Import apps policy
vault policy write apps policies/app-policy.hcl

# Create token with default policy to ensure that we cannot access secret
vault token create -policy default

# Login to vault with token provided inline
VAULT_TOKEN=<issued token> vault kv get secret/dev

# Create token with Apps policy and ask for the token to be wraped and with 120 sec ttl
vault token create -policy=apps -wrap-ttl=120

# Unwrap token in vault to retrieve the real issued token
VAULT_TOKEN=<wraped_token> vault unwrap

# Login with unwraped token and retrieve KV secret
VAULT_TOKEN=<unwraped_token> vault kv get secret/dev


#### Secrets engine demo
Handles cryptographic functions on data in-transit
Vault does not store the data is encrypts
Primary use case for Transit is to encrypt data from applications while storing that data in some primary datastore
Transit can sign and verify cryptographic signatures
Generate hashes of data (generate random bytes , ex passwords)
Algorithms used can be verified and audited centrally. Do not have to check developer code for used libraries.

# Enable transit engine
Vault secrets enable transit

# Create demo encryption key
vault write transit/keys/demo-key type=aes256-gcm96 

# Encrypt dummy data with demo key
vault write transit/encrypt/demo-key \
plaintext=$(base64 <<< "my secret data")

# Decrypt cyphertext with demo key
vault write transit/decrypt/demo-key \
ciphertext=<generated_cypher_text>

echo <decrypted_in_base64> | base64 --decode

## Encryption Key rotation
# Read key info and check version
vault read transit/keys/demo-key

# Rotate key
vault write -f transit/keys/demo-key/rotate

# Check new key version
vault read transit/keys/demo-key

# Rewrap cyphertext with new key version
vault write transit/rewrap/demo-key \
ciphertext=<previous_cyphertext>

# Test decrypt new cyphertext and check that plaintext content is the same

## Convergent Keys
# Create new encryption key with conversion_encription enabled
vault write -f transit/keys/convergent-key \
convergent_encryption=true derived=true

# Encrypt data with new encryption key and context and check that cyphertext is the same for the same context
vault write transit/encrypt/convergent-key \
plaintext=$(base64 <<< "my secret data") \
context=$(base64 <<< "appA")

## Backup vault
You can do file backups (snapshots) of standalone instances
Its is highly recomended that you use vault in a raft cluster (min 3 instances) in production. 
With raft storage backend mode you have snapshot backup and restore options available.