#!/bin/bash

# This script synchronizes Pebbles images from one registry to another.
# Set SRC_REPO and DST_REPO environment variables to override default source and destination.

# fail on errors, output what we are doing
set -e -x

SRC_REPO=${SRC_REPO:=docker-registry.rahti-int.csc.fi}
DST_REPO=${DST_REPO:=docker-registry.rahti.csc.fi}
IMAGES="pebbles pebbles-frontend filebeat logstash"

echo "pulling images from ${SRC_REPO}, tagging and pushing images to ${DST_REPO}"
for image in ${IMAGES}; do
  docker pull ${SRC_REPO}/pebbles-public-images/${image}
  docker tag ${SRC_REPO}/pebbles-public-images/${image} ${DST_REPO}/pebbles-public-images/${image}
  docker push ${DST_REPO}/pebbles-public-images/${image}
done
