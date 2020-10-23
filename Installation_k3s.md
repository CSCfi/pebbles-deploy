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

## Deprovisioning

Remove the Heat stacks for the environment in question. 

```bash
openstack stack delete -y --wait notebooks-dev-2-k3s 
openstack stack delete -y --wait notebooks-dev-2-k3s-volumes
```

*NOTE:* Deleting the volume stack will delete all data in the environment.
