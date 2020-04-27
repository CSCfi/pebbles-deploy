#!/usr/bin/env bash

set -e

env_name=${ENV_NAME}

print_header() {
    echo
    echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    echo "    $*"
    echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    echo
}

print_header "Initializing environment for $env_name"

if [[ ! -e /dev/shm/secret/vaultpass ]]; then
    mkdir -p /dev/shm/secret/
    touch /dev/shm/secret/vaultpass
    chmod 600 /dev/shm/secret/vaultpass
    if [[ -z ${VAULT_PASS} ]]; then
        read -s -p "vault password: " VAULT_PASS
        echo
    fi
    echo $VAULT_PASS > /dev/shm/secret/vaultpass
    echo "Wrote vault password to /dev/shm/secret/vaultpass"
    unset VAULT_PASS
fi

export ANSIBLE_INVENTORY=$HOME/pebbles-environments/$env_name
echo "ANSIBLE_INVENTORY set to $ANSIBLE_INVENTORY"

# initialize repositories if we are running in a CI pipeline
if [[ ! -z ${CI_COMMIT_REF_NAME} ]]; then
    print_header 'CI initialization starts'
    pushd . > /dev/null
    # copy source in place
    cp -r ${CI_PROJECT_DIR} /opt/deployment/pebbles
    # checkout pebbles-environments. match branch name if it exists
    cd /opt/deployment
    git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.csc.fi/pebbles/pebbles-environments.git
    cd /opt/deployment/pebbles-environments
    git checkout -b ${CI_COMMIT_REF_NAME} -t origin/${CI_COMMIT_REF_NAME} || true
    git pull
    # checkout pebbles-deploy. match branch name if it exists
    cd /opt/deployment
    git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.csc.fi/pebbles/pebbles-deploy.git
    cd /opt/deployment/pebbles-deploy
    git checkout -b ${CI_COMMIT_REF_NAME} -t origin/${CI_COMMIT_REF_NAME} || true
    git pull
    popd > /dev/null
    echo 'CI container initialization done'
fi

pushd /opt/deployment/pebbles-deploy/playbooks > /dev/null

if [[ -e requirements.yml ]]; then
    print_header "Installing galaxy-roles"
    ansible-galaxy install -f -p $HOME/galaxy-roles -r requirements.yml
fi

if [[ ! -e /dev/shm/${env_name}/deployment_data.sh ]]; then
  print_header "Initializing ramdisk contents"
  SKIP_DYNAMIC_INVENTORY=1 ansible-playbook initialize_ramdisk.yml
fi

print_header "Sourcing deployment data"
cat /dev/shm/${env_name}/deployment_data.sh
source /dev/shm/${env_name}/deployment_data.sh

if [[ -e /dev/shm/${env_name}/openrc.sh ]]; then
    print_header "Sourcing OpenStack credentials"
    source /dev/shm/${env_name}/openrc.sh
fi

if [[ "$SKIP_SSH_CONFIG" != "1" && "$DEPLOYMENT_TYPE" != 'helm' ]]; then
    # skip generation if the file is already there
    if [[ ! -e ~/.ssh/config ]]; then
        print_header "Generating ssh config entries"
        ansible-playbook generate_ssh_config.yml
    fi
fi

if [[ "$DEPLOYMENT_TYPE" == 'k3s' && ! -e ~/.kube/config ]]; then
    print_header "Fetching K3s credentials from master"
    ansible-playbook fetch_k3s_kubeconfig.yml
fi

popd > /dev/null

set +e

print_header "Initialization done"
