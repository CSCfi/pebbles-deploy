#!/bin/bash

# This script builds all pebbles images, saves them to file to a gitignored location that is synced to a virtual
# machine, and finally imports the images to the microk8s cluster running on the VM. This is handy for
# developing locally but running kubernetes remotely. Takes the remote server as the first argument and
# home directory of said server as the second argument (assuming that the source repositories are located there).
# Note that this script uses podman instead of docker.

DEST=$1
HOME_DIR=$2

# Build and sync pebbles
echo "Building image pebbles:latest"
pushd ~/src/gitlab.ci.csc.fi/pebbles/pebbles && podman build --tag pebbles:latest . --file=deployment/pebbles.Dockerfile ; popd

echo "Saving image pebbles:latest to file"
podman image save > ~/src/gitlab.ci.csc.fi/pebbles/pebbles/local_data/pebbles.img localhost/pebbles:latest

echo "Importing image pebbles:latest on VM"
ssh "$DEST" microk8s ctr image import "$HOME_DIR"/src/gitlab.ci.csc.fi/pebbles/pebbles/local_data/pebbles.img

# Build and sync frontends
for IMAGE in pebbles-frontend pebbles-admin-frontend
do
	echo "Building image $IMAGE:latest"
	pushd ~/src/gitlab.ci.csc.fi/pebbles/$IMAGE/ && podman build . -t $IMAGE:latest -f deployment/Dockerfile.multi-stage ; popd

	echo "Saving image $IMAGE:latest to file"
	podman image save > ~/src/gitlab.ci.csc.fi/pebbles/pebbles/local_data/$IMAGE.img localhost/$IMAGE:latest

	echo "Importing image $IMAGE:latest on VM"
	ssh "$DEST" microk8s ctr image import "$HOME_DIR"/src/gitlab.ci.csc.fi/pebbles/pebbles/local_data/$IMAGE.img
done
