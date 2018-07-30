# Pebbles deployment playbook with HEAT or OPENSHIFT

This repository contains an Ansible playbook to deploy [Pebbles](https://github.com/CSCfi/pebbles).

## OPENSHIFT (Beta)
WIP. This setup is only recommeded for development purposes.

### Environment requirements
- Ansible 2.5
- Python openshift library (pip install openshift)

### Provisioning

    $ ansible-playbook openshift_playbooks/provision_openshift.yml
    [give vault password when prompted]
    [provide a openshift project name when prompted]

### Monitoring

    $ oc get pods
    [Or via web interface of openshift]

### Deprovisioning

    $ oc delete dc --all
    $ oc delete secrets --all

## HEAT
It is assumed that you will have a separate repository with group_vars and
dynamic inventory as described [here](
https://github.com/CSCfi/pouta-ansible-cluster/blob/master/playbooks/openshift/README.md#advanced-deployment-mechanism-using-heat-for-automated-build-pipelines).


### Setting up environment

1. Create a virtualenv and install requirerements.txt .
2. Clone the configuration repository, optionally symlink it as environments
   under the current repo. This is the default but not strictly necessary.
3. $ source project openrc.sh to set environment variables

### Provisioning and configuring

    $ workon pebbles-deploy
    (pebbles-deploy) $ ansible-playbook -i environments/[environment-name]/ -e
    "cluster_name=environment-name" playbooks/site.yml
    [give vault password when prompted]

### Deprovisioning

    $ workon pebbles-deploy
    (pebbles-deploy) $ ansible-playbook -i environments/[environment-name]/ -e
    "cluster_name=environment-name" playbooks/deprovision_heat.yml
    [give vault password when prompted]

Note that if you have provisioned a stack for hard drives it will *not* be
destroyed by deprovision_heat.yml at the moment. You have to manually remove
that stack from OpenStack UI. This is so that we can shut down QA environments
and re-provision and reinstall from scratch without losing state like docker
images on the pebbles host.

Note: the inventory is a *directory* not just the hosts file.
