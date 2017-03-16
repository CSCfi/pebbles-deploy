# Pebbles deployment playbook

This repository contains an Ansible playbook to deploy [Pebbles](https://github.com/CSC-IT-Center-for-Science/pebbles).


### Production

The production deployment has been envisioned as follows

![pebbles schematic](https://cloud.githubusercontent.com/assets/609234/24000118/0d0b5dd4-0a63-11e7-8920-9d9a0841c5e3.png)

To run in production create an Ansible hosts file e.g.

  docker_host ansible_host=192.168.44.147  ansible_user=cloud-user

To install in production edit production_vars.yml to suit your purposes and
run

  $ ansible-playbook playbook.yml -e @production_vars.yml

This way it is possible to have multiple extra variable files for multiple
instances of the software if needed.

The playbook installs docker on a (remote) host and installs a number of
containers. For the purpose of managing the containers ports 2220:2230 should
be open between the deploying host and the remote host.

### Local installation

It *should* be possible to install the machine locally inside a Vagrant virtual
machine but that hasn't been tested with the new system. That way one can edit
the files locally on a mounted directory.

If done, one should set ansible_host to point to the vagrant system, and set
the installation to standalone. Pull requests are welcome.

## Secrets

Currently the system expects to find the following files in the directory
pointed to by local_secrets_path on the deploying machine.

Compulsory for production

* creds: provisioning credentials for the OpenStack installation

Optional for SSL
* server.crt.chained
* server.key, SSL x.509 (chained) certificate file and private key in a format
  nginx understands

If these are not present, a self-signed certificate is created.

Optional for SSO
* sp_cert.pem
* sp_key.pem
Service provider key and certificate signed by CA.

To enable creation of the SSO container set in production_vars.yml

  use_sso: True

and the following variables with appropriate values from your IDP

  shibboleth_entity_id
  shibboleth_discovery_url
  shibboleth_metadata_url
  shibboleth_support_contact

** it is nontrivial to enable shibboleth after initial installation **

### Firewall rules

To work, the following things are required for a production installation:

* allow port 443 to pebbles host
* allow ports 22, and 2222-22225 to pebbles host from pebbles bastion
* allow TCP and UDP traffic out from the server

