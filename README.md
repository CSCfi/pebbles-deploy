# Pebbles deployment with Ansible, Heat and Helm

This repository contains Ansible playbooks and Helm charts to deploy [Pebbles](https://github.com/CSCfi/pebbles)
on CSC's computing platforms. It could serve as an example for other deployments.

## Prerequisites for using these playbooks

All that is needed is

- a working Docker installation
- git client
- access to repositories

## Installation instructions

For setting up a local development environment, see 
[Installation_for_local_development.md](Installation_for_local_development.md)

For setting up a development environment on OpenShift for release-5, see 
[Installation_on_openshift.md](Installation_on_openshift.md)

For deploying a GitLab runner, see [Installation_gitlab_runner.md](Installation_gitlab_runner.md). 

For deploying K3s for deploying user workloads and/or Pebbles, see [Installation_k3s.md](Installation_k3s.md).

For deploying a bunch of Postgresql databases, see [Installation_db_farm.md](Installation_db_farm.md). 
