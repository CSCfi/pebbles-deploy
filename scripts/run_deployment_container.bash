#!/usr/bin/env bash

# Script to run a temporary deployment container. Should be executed in
# playbooks/pebbles-deploy directory. Use sudo if that is required for
# launching docker/podman. Further sessions can be opened by running
#
#  $DOCKER_EXECUTABLE exec -it [environment_name]-deployer bash

# if environment variable DOCKER_EXECUTABLE is not set, use docker as default
DOCKER_EXECUTABLE="${DOCKER_EXECUTABLE:-docker}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo "  -E key=value             set additional environment variables (can use -E multiple times)"
    echo "  -c container_image       use custom container image (default 'cscfi/pebbles-deployer')"
    echo "  -t image_tag             use custom container image tag (default 'latest')"
    echo "  -s                       skip ssh config generation (useful when debugging broken installations)"
    echo "  -d                       development mode"
    exit 1
}

docker_opts='-it'
container_image='cscfi/pebbles-deployer'
image_tag='latest'
development_mode=0

while getopts "p:P:e:E:o:c:t:shd" opt; do
    case $opt in
    p)
        passfile=$OPTARG
        if [[ ! -e $passfile ]]; then
            echo "vault password file '$passfile' does not exist"
            exit 1
        fi
        docker_opts="$docker_opts -v $passfile:/dev/shm/secret/vaultpass:ro"
        ;;
    P)
        passfile=$OPTARG
        if [[ ! -e $passfile ]]; then
            echo "vault password file '$passfile' does not exist"
            exit 1
        fi
        docker_opts="$docker_opts -e VAULT_PASS=$(cat $passfile)"
        ;;
    e)
        env_name=$OPTARG
        docker_opts="$docker_opts -e ENV_NAME=$env_name"
        ;;
    E)
        docker_opts="$docker_opts -e $OPTARG"
        ;;
    c)
        container_image=$OPTARG
        echo "  using custom image '$container_image'"
        ;;
    t)
        image_tag=$OPTARG
        echo "  using custom image tag '$image_tag'"
        ;;
    s)
        docker_opts="$docker_opts -e SKIP_SSH_CONFIG=1"
        ;;
    d)
        development_mode=1
        ;;
    *)
        print_usage_and_exit
        ;;
    esac
done
shift "$((OPTIND - 1))"

if [ "$development_mode" == "1" ]; then
    echo '###########################################################################################'
    echo '#                                                                                         #'
    echo '#   Development mode - loopback mounting all pebbles repositories under /opt/deployment   #'
    echo '#                                                                                         #'
    echo '###########################################################################################'
    $DOCKER_EXECUTABLE run --rm \
        -v $SCRIPT_DIR/../../pebbles:/opt/deployment/pebbles:rw \
        -v $SCRIPT_DIR/../../pebbles-environments:/opt/deployment/pebbles-environments:rw \
        -v $SCRIPT_DIR/../../pebbles-deploy:/opt/deployment/pebbles-deploy:rw \
        -v $SCRIPT_DIR/../../pebbles-frontend:/opt/deployment/pebbles-frontend:rw \
        -v $SCRIPT_DIR/../../pebbles-admin-frontend:/opt/deployment/pebbles-admin-frontend:rw \
        -v $SCRIPT_DIR/../../pebbles-status-display:/opt/deployment/pebbles-status-display:rw \
        -v $SCRIPT_DIR/../../imagebuilder:/opt/deployment/imagebuilder:rw \
        --name ${env_name}-deployer \
        $docker_opts \
        -e DEVELMODE=1\
        $container_image:$image_tag $*
else
    $DOCKER_EXECUTABLE run --rm \
        -v $SCRIPT_DIR/../../pebbles-environments:/opt/deployment/pebbles-environments:rw \
        --name ${env_name}-deployer \
        $docker_opts \
        $container_image:$image_tag $*
fi
