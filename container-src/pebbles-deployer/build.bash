#!/usr/bin/env bash

# A simple script to build poc-deployer locally
# The default container image tag is `cscfi/pebbles-deployer:latest`
# How to run: ./build.bash <container_image_name_and_tag>

set -ex

# if environment variable DOCKER_EXECUTABLE is not set, use docker as default
DOCKER_EXECUTABLE="${DOCKER_EXECUTABLE:-docker}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_AND_TAG=${1-cscfi/pebbles-deployer:latest}

$DOCKER_EXECUTABLE build --pull=true -t ${IMAGE_AND_TAG} $SCRIPT_DIR
