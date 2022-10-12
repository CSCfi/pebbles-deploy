# Installing K3s cluster

Here we have instructions to deploy K3s cluster on CSCfi Pouta OpenStack cloud.

## Prerequisites

See [Using_deployment_container.md](Using_deployment_container.md) for prerequisites, checking out the repositories and
launching a deployment container.

## Provisioning and configuring

Open a deployment container for the K3s environment (for example `notebooks-dev-2-k3s`). Change to pebbles-deploy
directory and run site_k3s.yml to provision base resources.

```bash
cd pebbles-deploy
ansible-playbook -v playbooks/site_k3s.yml
```

For initial installation, you can also specify additional variable `server_update_and_reboot=1`, that will update all OS
packages on the hosts and reboot if any changes were detected. This will only run on new hosts without the installation
flag present in /var/lib/pb/INSTALLED in place. Note that you may need to retry the step, OS update could take a very
long time and ssh connection problems might occur.

To add nodes for user workloads, provision individual Fedora CoreOS VMs with:

```bash
cd pebbles-deploy
ansible-playbook -v playbooks/deploy_fcos_node.yml
```

Optionally, you can add `-e fcos_upgrade_on_first_boot=1` to the playbook command to upgrade the OS to the latest
during the first boot.

## Deprovisioning

First remove the node VMs.

```bash
openstack server list | grep dev-cluster-X-node
openstack server delete fcos_node_from_above
```

Remove the Heat stacks for the environment in question.

```bash
openstack stack delete --wait dev-cluster-X 
openstack stack delete --wait dev-cluster-X-volumes
```

*NOTE:* Deleting the volume stack will delete all data in the environment.
