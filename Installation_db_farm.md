# Installing Postgresql database VMs

Here we have instructions to deploy Postgresql databases in one or more FCOS VMs. The databases run in podman 
containers, and there can be multiple DBs per host. All configuration is done up-front via butane/ignition. Database
contents are saved on separate volumes.

## Prerequisites

See [Installation_release-4.md](Installation_release-4.md) for prerequisites, 
checking out the repositories and launching a deployment container.

## Provisioning and configuring

An example inventory for a database host with 3 databases:

```yaml
all:
  vars:
    cluster_name: dev-db-farm
    deployment_type: db-farm
    router: ""
    network: ""
  children:
    dbservers:
      hosts:
        db-1:
          public_ip: ""
          allow_ssh_from:
            - "" 
          flavor: standard.small
          image: fedora-coreos-35.20220116.3.0-openstack.x86_64.qcow2
          volume_size_gb: 10
          lock_server: false
          databases:
            - name: dev-1
              image: docker.io/library/postgres:13.5
              port: 12341
              password: "{{ vaulted_database_passwords['dev-1'] }}"
              allow_access_from:
                - ""
            - name: dev-2
              image: docker.io/library/postgres:14
              port: 12342
              password: "{{ vaulted_database_passwords['dev-2'] }}"
              allow_access_from:
                - ""
            - name: dev-3
              image: docker.io/library/postgres:latest
              port: 12343
              password: "{{ vaulted_database_passwords['dev-3'] }}"
              allow_access_from:
                - ""
```

To deploy, open a deployment container for the db-farm environment (called 'dev-db-farm' or similar).
Change to pebbles-deploy directory and run site_db_farm.yml 

```bash
cd pebbles-deploy
ansible-playbook -v playbooks/site_db_farm.yml
```

## Deprovisioning

Simply remove the VMs, security groups and related volumes.

```bash
openstack server delete SERVER_NAME
openstack security group delete GROUP_NAME
openstack volume delete VOLUME_NAME

```
