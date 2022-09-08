# Installing GitLab runner for CI/CD

Here we have instructions to deploy a VM based GitLab runner.

## Prerequisites

See [Using_deployment_container.md](Using_deployment_container.md) for prerequisites, 
checking out the repositories and launching a deployment container.

## Provisioning and configuring

Open a deployment container for the gitlab runner environment (called 'gitlab-runner' or similar).
Change to pebbles-deploy directory and run site_gitlab_runner.yml 

```bash
cd pebbles-deploy
ansible-playbook -v playbooks/site_gitlab_runner.yml
```

## Deprovisioning

Simply remove the Heat stack for the environment in question.

```bash
openstack stack remove STACK_NAME
```
