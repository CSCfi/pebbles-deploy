# Pebbles deployment playbook

This repository contains an Ansible playbook to deploy Pebbles.

With defaults it installs everything for a web developer, i.e. inside a single
container with the program folder on localhost mounted as a volume inside a
container.

To install locally run vagrant to create a virtual machine, add it to your
./hosts  and run with the default parameters.

To install in production edit production_vars.yml to suit your purposes and
run

  $ ansible-playbook playbook.yml -e @production_vars.yml

This way it is possible to have multiple extra variable files for multiple
instances of the software if needed.

The playbook installs docker on a (remote) host and installs a number of
containers. For the purpose of managing the containers ports 2220:2230 should
be open between the deploying host and the remote host.

## Secrets

Currently the system expects to find the following files in the directory
pointed to by local_secrets_path

Compulsory

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

and the following variables with appropriate values

  shibboleth_entity_id
  shibboleth_discovery_url
  shibboleth_metadata_url
  shibboleth_support_contact


