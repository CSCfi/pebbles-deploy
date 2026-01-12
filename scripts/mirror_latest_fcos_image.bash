#!/usr/bin/env bash
#
# Script that downloads latest Fedora CoreOS image and uploads it to OpenStack
#
# Set the release stream with FCOS_STREAM variable, default is "stable". Use "next" for bleeding edge.
#

# bail out on any error
set -e

FCOS_STREAM=${FCOS_STREAM:-stable}

METADATA_URL=https://builds.coreos.fedoraproject.org/streams/${FCOS_STREAM}.json

# get metadata
metadata_file=$(mktemp)
curl -s ${METADATA_URL} > ${metadata_file}

# extract needed pieces of info
release=$(jq -r '.architectures.x86_64.artifacts.openstack.release' < ${metadata_file})
image_url=$(jq -r '.architectures.x86_64.artifacts.openstack.formats["qcow2.xz"].disk.location' < ${metadata_file})
sha256=$(jq -r '.architectures.x86_64.artifacts.openstack.formats["qcow2.xz"].disk.sha256' < ${metadata_file})

rm ${metadata_file}

echo
echo "the latest stable image"
echo "-----------------------"
echo "  release: ${release}"
echo "image_url: ${image_url}"
echo "   sha256: ${sha256}"

image_name="fedora-coreos-${release}-openstack.x86_64.qcow2"

echo
echo checking that image does not already exist in OpenStack
openstack image show ${image_name} > /dev/null 2>&1 \
  && echo "error: image ${image_name} already exists" && echo && exit 1

echo
echo downloading image
curl -o "/tmp/${image_name}.xz" -C - ${image_url}

echo
echo verifying downloaded image
echo "${sha256} /tmp/${image_name}.xz" > "/tmp/${image_name}.sha256"
sha256sum -c "/tmp/${image_name}.sha256"

echo
echo uploading uncompressed image as ${image_name}
xzcat "/tmp/${image_name}.xz" | openstack image create --container-format=bare --disk-format=qcow2 ${image_name}

echo
echo done
echo
