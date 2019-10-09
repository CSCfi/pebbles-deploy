#!/usr/bin/env bash

set -e

env_name=$ENV_NAME

echo "Initializing environment for $env_name"
echo

if [[ ! -e /dev/shm/secret/vaultpass ]]; then
    mkdir -p /dev/shm/secret/
    touch /dev/shm/secret/vaultpass
    chmod 600 /dev/shm/secret/vaultpass
    if [ -z $VAULT_PASS ]; then
        read -s -p "vault password: " VAULT_PASS
        echo
    fi
    echo $VAULT_PASS > /dev/shm/secret/vaultpass
    echo "Wrote vault password to /dev/shm/secret/vaultpass"
    unset VAULT_PASS
fi

export ANSIBLE_INVENTORY=$HOME/pebbles-environments/$env_name
echo "ANSIBLE_INVENTORY set to $ANSIBLE_INVENTORY"
echo

pushd /opt/deployment/pebbles-deploy/playbooks > /dev/null

if [[ -e requirements.yml ]]; then
  echo "Installing galaxy-roles"
  echo
  ansible-galaxy install -f -p $HOME/galaxy-roles -r requirements.yml
fi

echo "Initializing ramdisk contents"
echo
SKIP_DYNAMIC_INVENTORY=1 ansible-playbook initialize_ramdisk.yml
echo

if [[ -e /dev/shm/$env_name/openrc.sh ]]; then
  echo "Sourcing OpenStack credentials"
  source /dev/shm/$env_name/openrc.sh
fi

if [[ -e /dev/shm/$env_name/deployment_data.sh ]]; then
  echo "Sourcing deployment data"
  source /dev/shm/$env_name/deployment_data.sh
fi

popd > /dev/null

set +e
