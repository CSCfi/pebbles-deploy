#!/usr/bin/env bash

# This script generates a certificate request and private key.
#
# Certificate request is placed in /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.req
# Private key is put into ansible vault in the inventory.
#

set -eu -o pipefail

echo "Generating certificate key and request for $PUBLIC_DOMAIN_NAME"

mkdir -p /dev/shm/cert
openssl req -newkey rsa:4096 -sha512 -noenc \
  -subj "/CN=${PUBLIC_DOMAIN_NAME}" \
  -out /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.req \
  -keyout /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.key

echo "Wrote request and key in /dev/shm/cert"

echo "Generating temporary key file for ansible vault encryption"
cat > /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.vaulttmp << EOF
# Script generated certificate file
---
vaulted_private_ssl_key: |
EOF

sed -e 's/^/  /' /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.key >> /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.vaulttmp

echo "Encrypting key and replacing $ENV_BASE_DIR/group_vars/all/vault_cert.yml"
ansible-vault encrypt /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.vaulttmp --output $ENV_BASE_DIR/group_vars/all/vault_cert.yml

rm /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.{vaulttmp,key}

echo "Request file openssl output"
openssl req -text -noout -in /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.req

echo "Send the request file to the CA for obtaining the certificate"
echo
cat /dev/shm/cert/${PUBLIC_DOMAIN_NAME}.req
echo
