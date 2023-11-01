# Installing K3s cluster

Here we have instructions to deploy K3s cluster on CSCfi Pouta OpenStack cloud.

## Overview

The core installation of our k3s cluster consists of three VMs:

* master: runs all system components, handles external traffic
* nfs: NFS server for persistent storage
* jump: ssh gateway, k3s-autoscaler

All core hosts are running EL-compatible OS, such as AlmaLinux.

In addition to core VMs, nodes for user workloads are provisioned either manually or by k3s-autoscaler. Nodes run on
Fedora CoreOS.

## Prerequisites

See [Using_deployment_container.md](Using_deployment_container.md) for prerequisites, checking out the repositories and
launching a deployment container.

## Provisioning and configuring the base system

Open a deployment container for the K3s environment (for example `dev-cluster-2`). Change to `pebbles-deploy`
directory and run `site_k3s.yml` to provision base system.

```bash
cd pebbles-deploy
ansible-playbook -v playbooks/site_k3s.yml
```

For initial installation, you can also specify additional variable `server_update_and_reboot=1`, that will update all OS
packages on the hosts and reboot if any changes were detected. This will only run on new hosts without the installation
flag present in `/var/lib/pb/INSTALLED` in place. Note that you may need to retry the step, OS update could take a very
long time and ssh connection problems might occur.

## Adding nodes to run user sessions

If `k3s-autoscaler` installation is enabled, nodes for user workloads are deployed automatically by the autoscaler.
To add nodes *manually* for user workloads, provision individual Fedora CoreOS VMs with:

```bash
cd pebbles-deploy
ansible-playbook -v playbooks/deploy_fcos_node.yml
```

Optionally, you can add `-e fcos_upgrade_on_first_boot=1` to the playbook command to upgrade the OS to the latest
during the first boot.

## Deprovisioning

First remove the node VMs - they not part of the stack but using shared stack provisioned resources.

```bash
openstack server list | grep dev-cluster-X-node
openstack server delete fcos_node_1_from_above
openstack server delete fcos_node_2_from_above
...
```

Remove the Heat stacks for the environment in question.

```bash
openstack stack delete --wait dev-cluster-X
openstack stack delete --wait dev-cluster-X-volumes
```

**NOTE:** Deleting the volume stack will **delete all data** in the environment.

## Nfs-provisioner

K3s deployment uses https://github.com/kubernetes-sigs/nfs-ganesha-server-and-external-provisioner to dynamically create
exports on NFS node for persistent storage. Installation will download a ready-built binary from Allas object storage.

If you need to create a new binary, run the respective playbook:

```bash
cd ~/pebbles-deploy && ansible-playbook playbooks/build_nfs-provisioner.yml
```

Upload the binary to object storage and set the version variable `provisioner_binary_version` in your inventory.

See `build_nfs-provisioner.yml` playbook and `nfs_provisioner` role for more details.
