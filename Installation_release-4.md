# Installation for release-4

Here we have instructions to deploy a VM based pebbles release-4 with Heat.

## Prerequisites

Clone pebbles, pebbles-deploy and pebbles-environments.

```bash
mkdir -p ~/src/gitlab.csc.fi/pebbles
cd ~/src/gitlab.csc.fi/pebbles/
git clone https://gitlab.csc.fi/pebbles/pebbles
git clone https://gitlab.csc.fi/pebbles/pebbles-deploy
git clone https://gitlab.csc.fi/pebbles/pebbles-environments
```

We have a deployment container with all dependencies preinstalled. To build the container,
run the build script located in `pebbles-deploy/container-src/pebbles-deployer`:

```bash
cd ~/src/gitlab.csc.fi/pebbles/pebbles-deploy/container-src/pebbles-deployer

# use sudo if needed
./build.bash
```

__Note on SELinux__: If you are running under SELinux enforcing mode, the container processes
may not be able to access the volumes by default. To enable access from containerized
processes, change the labels on the mounted directories:

```bash
cd ~/src/gitlab.csc.fi/pebbles/
chcon -Rt svirt_sandbox_file_t pebbles*
```
## Launching a deployment container

Deployments are done in a dedicated Docker container. Different environments will have dedicated instances.

Here we launch a container for development environment called 'notebooks-dev'.

```bash
cd ~/src/gitlab.csc.fi/pebbles/pebbles-deploy/
./scripts/run_deployment_container.bash -e notebooks-dev 

```
The container will ask for Ansible vault password for that environment at startup. Then it will set up
the environment ready for deployment, including ssh configuration, ssh keys, certificates, deployment robot credentials
etc.

If you want to automate the process or repeat running single actions containerized, you
can create a vault password file and loopback mount it to the container so that
initialization playbook does not have to ask it interactively. There is a
script called `read_vault_pass_from_clipboard.bash` under the scripts directory
for doing this.

## Provisioning and configuring

In the deployment container, first check that you are on the branches that you wish to use. The branches will mounted
from your laptop's directory. Check out the branches on your laptop and double check with branch-info 

```bash
branch-info
```

Then simply change to pebbles-deploy directory and run site. 

```bash
cd pebbles-deploy
ansible-playbook -v playbooks/site.yml
```

## Deprovisioning

```bash
cd pebbles-deploy
ansible-playbook -v playbooks/deprovision_heat.yml
```

Note that if you have provisioned a stack for hard drives it will *not* be
destroyed by deprovision_heat.yml at the moment. You have to manually remove
that stack from OpenStack UI or command line in the deployment container. This is so that
we can shut down QA environments and re-provision and reinstall from scratch without losing 
state like database or docker images on the main server host.
