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

export ENV_BASE_DIR=$HOME/pebbles-environments/$env_name

# initialize repositories if we are running in a CI pipeline
if [[ ! -z ${CI_COMMIT_REF_NAME} ]]; then
    print_header 'CI initialization starts'
    pushd . > /dev/null
    # pebbles: clone and checkout branch if it exists
    cd /opt/deployment
    git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/pebbles/pebbles.git
    cd /opt/deployment/pebbles
    git checkout -b ${PEBBLES_COMMIT_REF_NAME} -t origin/${PEBBLES_COMMIT_REF_NAME} || true
    git pull
    # pebbles-environments: clone and checkout branch if it exists
    cd /opt/deployment
    git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/pebbles/pebbles-environments.git
    cd /opt/deployment/pebbles-environments
    git checkout -b ${PEBBLES_ENVIRONMENTS_COMMIT_REF_NAME} -t origin/${PEBBLES_ENVIRONMENTS_COMMIT_REF_NAME} || true
    git pull
    # pebbles-deploy: remove the existing repo if it is already in the image, then clone and checkout branch if it exists
    cd /opt/deployment
    if [ -d "pebbles-deploy" ]; then
     echo "Removing existing pebbles-deploy directory"
     rm -rf pebbles-deploy
    fi
    git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/pebbles/pebbles-deploy.git
    cd /opt/deployment/pebbles-deploy
    git checkout -b ${PEBBLES_DEPLOY_COMMIT_REF_NAME} -t origin/${PEBBLES_DEPLOY_COMMIT_REF_NAME} || true
    git pull
    # imagebuilder: clone and checkout branch if it exists
    cd /opt/deployment
    git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/pebbles/imagebuilder.git
    cd /opt/deployment/imagebuilder
    git checkout -b ${IMAGEBUILDER_COMMIT_REF_NAME} -t origin/${IMAGEBUILDER_COMMIT_REF_NAME} || true
    git pull
    popd > /dev/null
    echo 'CI initialization done'
fi

# New style environment definition without Ansible
if [[ -e $ENV_BASE_DIR/.env.yaml ]]; then
    echo "found .env.yaml in environment base directory, using init_env.py"
    $HOME/bin/init_env.py
# Ansible inventory based environment
else
    # read vault pass if necessary (skip when launching addition shells in an existing container)
    if [[ ! -e /dev/shm/secret/vaultpass ]]; then
        mkdir -p /dev/shm/secret/
        touch /dev/shm/secret/vaultpass
        chmod 600 /dev/shm/secret/vaultpass
        if [[ -e /run/pebbles/secret/vaultpass_$env_name ]]; then
            cp /run/pebbles/secret/vaultpass_$env_name /dev/shm/secret/vaultpass
            echo "vaultpass is copied for $env_name"
        else
           if [[ -z ${VAULT_PASS} ]]; then
               read -s -p "vault password: " VAULT_PASS
           fi
           echo $VAULT_PASS > /dev/shm/secret/vaultpass
           echo "Wrote vault password to /dev/shm/secret/vaultpass"
           unset VAULT_PASS
        fi
    fi
    export ANSIBLE_INVENTORY=$ENV_BASE_DIR
    echo "ANSIBLE_INVENTORY set to $ANSIBLE_INVENTORY"
fi

pushd /opt/deployment/pebbles-deploy/playbooks > /dev/null

if [[ ! -e /dev/shm/${env_name}/deployment_data.sh ]]; then
    print_header "Initializing ramdisk contents"
    ansible-playbook initialize_ramdisk.yml
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

# Set up custom prompt. Make production deployments stand out.
# More info on format: https://unix.stackexchange.com/questions/105958/terminal-prompt-not-wrapping-correctly
case $DEPLOYMENT_ROLE in
production)
    export PS1='\[${YELLOW}\]\[${RED_BG}\]${ENV_NAME}\[${RESET}\] $(short_cwd) \[${GREEN}\]($(parse_git_branch))\[${RESET}\]\n\D{%Y%m%d-%H:%M:%S}> '
    ;;
qa)
    export PS1='\[${YELLOW}\]\[${BLUE_BG}\]${ENV_NAME}\[${RESET}\] $(short_cwd) \[${GREEN}\]($(parse_git_branch))\[${RESET}\]\n\D{%Y%m%d-%H:%M:%S}> '
    ;;
*)
    export PS1='\[${YELLOW}\]${ENV_NAME}\[${RESET}\] $(short_cwd) \[${GREEN}\]($(parse_git_branch))\[${RESET}\]\n\D{%Y%m%d-%H:%M:%S}> '
    ;;
esac

popd > /dev/null

set +e

print_header "Initialization done"
touch /dev/shm/initialization_done
