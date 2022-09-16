#!/usr/bin/env bash
#
# Script that pulls given images on all k3s nodes labeled with role=user
#
# Requires working passwordless ssh to nodes
#

# bail out on any error
set -e
images=$*

nodes=$(oc get nodes -l role=user -o name | sed -e 's|node/||g')
for image in $images; do
    for node in $nodes; do
        echo "pulling $image on $node"
        ssh -q $node sudo /usr/local/bin/k3s crictl pull $image
        echo
    done
done
