#!/usr/bin/env bash

# A simple script to build poc-deployer locally
# The default container image tag is `cscfi/poc-deployer`
# How to run: ./build.bash <container_image_tag>

set -ex

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

docker build --pull=true -t ${1-cscfi/pebbles-backup} $SCRIPT_DIR
