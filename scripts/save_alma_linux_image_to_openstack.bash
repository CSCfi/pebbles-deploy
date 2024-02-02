#!/usr/bin/env bash

# Download a file for an AlmaLinux image and create an openstack image from it.
# Usage: define major version number as the first argument, minor as the second argument and date tag as the third
# argument. E.g.:
# bash save_alma_linux_image_to_openstack.bash 8 9 20231128

# bail out on any error
set -e

if [ ! $# -eq 3 ]
  then
    echo Please provide 3 arguments: the major version, minor version and tag.
fi

major=$1
minor=$2
tag=$3
version=$major.$minor-$tag
image_name=AlmaLinux-$major-GenericCloud-$version.x86_64.qcow2

echo
echo attempting to download $image_name
echo
echo checking that image does not already exist in OpenStack
echo
openstack image show $image_name > /dev/null 2>&1 \
  && echo "error: image $image_name already exists" && echo && exit 1

curl --fail https://www.nic.funet.fi/pub/Linux/INSTALL/almalinux/$major/cloud/x86_64/images/$image_name -o /tmp/$image_name
curl --fail https://www.nic.funet.fi/pub/Linux/INSTALL/almalinux/$major/cloud/x86_64/images/CHECKSUM -o /tmp/CHECKSUM
(cd /tmp/ && sha256sum --ignore-missing -c /tmp/CHECKSUM)
openstack image create --container-format=bare --disk-format=qcow2 --file /tmp/$image_name $image_name
