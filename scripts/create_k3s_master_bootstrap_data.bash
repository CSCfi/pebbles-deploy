#!/usr/bin/env bash

# This script will create an Ansible vault file for master bootstrap data.
# It should be run in the deployment container against an existing K3s deployment
#
# The reason for having bootstrap data is to preserve credentials between development system reinstallations.

set -e

OUTPUT_FILE=/tmp/vault_master_bootstrap.yml

# temp file for encoded tarball
enc_file=$(mktemp)

# create an encoded tar archive of k3s server cred and tls directories
ssh $ENV_NAME-master sudo tar cvz -C / var/lib/rancher/k3s/server/{cred,tls} |
  base64 >$enc_file

# construct vaulted file
vault_file=$(mktemp)
echo '---' >$vault_file
echo 'vaulted_master_bootstrap_data: |' >>$vault_file
sed -e 's/^/  /g' $enc_file >>$vault_file

# encrypt vault
ansible-vault encrypt $vault_file --output $OUTPUT_FILE

# remove temporary files
rm -f $enc_file $vault_file

echo
echo "master bootstrap data vault file was saved to $OUTPUT_FILE"
echo
