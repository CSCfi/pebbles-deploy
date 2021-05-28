#!/usr/bin/env bash

# Script to run a temporary deployment container. Should be executed in
# playbooks/pebbles-deploy directory. Use sudo if that is required for
# launching docker. Further sessions can be opened by running
#
#  docker exec -it [environment_name]-deployer bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

print_usage_and_exit() {
    me=$(basename "$0")
    echo
    echo "Usage: $me [options] [container arguments]"
    echo "  where options are"
    echo "  -p vault_password_file   path to file containing vault password"
    echo "                           mounted to /dev/shm/secrets/vaultpass"
    echo "  -P vault_password_file   path to file containing vault password"
    echo "                           exposed as environment variable VAULT_PASS"
    echo "  -e environment_name      environment to deploy"
    echo "  -c container_image       use custom container image (default cscfi/pebbles-deployer)"
    echo "  -s                       skip ssh config generation (useful when debugging broken installations)"
    exit 1
}

docker_opts='-it'
container_image='cscfi/pebbles-deployer'

while getopts "p:P:e:o:c:sh" opt; do
    case $opt in
        p)
            passfile=$OPTARG
            if [[ ! -e $passfile ]]; then
                echo "vault password file $passfile does not exist"
                exit 1
            fi
            docker_opts="$docker_opts -v $passfile:/dev/shm/secret/vaultpass:ro"
            ;;
        P)
            passfile=$OPTARG
            if [[ ! -e $passfile ]]; then
                echo "vault password file $passfile does not exist"
                exit 1
            fi
            docker_opts="$docker_opts -e VAULT_PASS=$(cat $passfile)"
            ;;
        e)
            env_name=$OPTARG
            docker_opts="$docker_opts -e ENV_NAME=$env_name"
            ;;
        c)  container_image=$OPTARG
            echo "  using custom image $container_image"
            ;;
        s)
            docker_opts="$docker_opts -e SKIP_SSH_CONFIG=1"
            ;;
        *)
            print_usage_and_exit
            ;;
    esac
done
shift "$((OPTIND-1))"

docker run --rm \
    -v $SCRIPT_DIR/../../pebbles:/opt/deployment/pebbles:rw \
    -v $SCRIPT_DIR/../../pebbles-environments:/opt/deployment/pebbles-environments:rw \
    -v $SCRIPT_DIR/../../pebbles-deploy:/opt/deployment/pebbles-deploy:rw \
    -v $SCRIPT_DIR/../../pebbles-frontend:/opt/deployment/pebbles-frontend:rw \
    --name ${env_name}-deployer \
    $docker_opts \
    $container_image $*
