# Installing K3s cluster

Here we have instructions to deploy K3s cluster on CSCfi Pouta OpenStack cloud.

## Prerequisites

See [Installation_release-4.md](Installation_release-4.md) for prerequisites, 
checking out the repositories and launching a deployment container.

## Provisioning and configuring

Open a deployment container for the K3s environment (for example `notebooks-dev-2-k3s`).
Change to pebbles-deploy directory and run site_k3s.yml 

```bash
cd pebbles-deploy
ansible-playbook -v playbooks/site_k3s.yml
```

For initial installation, you can also specify additional variable `server_update_and_reboot=1`, that will
update all OS packages on the hosts and reboot if any changes were detected. Do *not* use this for a *running* 
system that has any workloads. Also note that you may need to retry the step, OS update could take a very long time
and ssh connection problems might occur.

## Deprovisioning

Remove the Heat stacks for the environment in question. 

```bash
openstack stack delete -y --wait notebooks-dev-X-k3s 
openstack stack delete -y --wait notebooks-dev-X-k3s-volumes
```

*NOTE:* Deleting the volume stack will delete all data in the environment.