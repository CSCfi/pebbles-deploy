# Using deployment container

## Prerequisites

Clone pebbles, pebbles-frontend, pebbes-admin-frontend, pebbles-deploy, pebbles-environments and imagebuilder

```bash
mkdir -p ~/src/gitlab.ci.csc.fi/pebbles
cd ~/src/gitlab.ci.csc.fi/pebbles/
git clone https://gitlab.ci.csc.fi/pebbles/pebbles
git clone https://gitlab.ci.csc.fi/pebbles/pebbles-frontend
git clone https://gitlab.ci.csc.fi/pebbles/pebbles-admin-frontend
git clone https://gitlab.ci.csc.fi/pebbles/pebbles-deploy
git clone https://gitlab.ci.csc.fi/pebbles/pebbles-environments
git clone https://gitlab.ci.csc.fi/pebbles/imagebuilder
```

We have a deployment container with all dependencies preinstalled. To build the container,
run the build script located in `pebbles-deploy/container-src/pebbles-deployer`:

```bash
# use sudo if needed
~/src/gitlab.ci.csc.fi/pebbles/pebbles-deploy/container-src/pebbles-deployer/build.bash
```

__Note on SELinux__: If you are running under SELinux enforcing mode, the container processes
may not be able to access the volumes by default. To enable access from containerized
processes, change the labels on the mounted directories:

```bash
cd ~/src/gitlab.ci.csc.fi/pebbles/
chcon -Rt svirt_sandbox_file_t pebbles*
```

## Launching a deployment container

Deployments are done in a dedicated Docker container. Different environments will have dedicated instances.

Here we launch a container for development environment called 'pebbles-devel-1'.

```bash
cd ~/src/gitlab.ci.csc.fi/pebbles/pebbles-deploy/
./scripts/run_deployment_container.bash -e pebbles-devel-1 

```

The container will ask for Ansible vault password for or Age key that environment at startup. Then it will set up
the environment ready for deployment, including ssh configuration, ssh keys, certificates, deployment robot credentials
etc.

If you want to automate the process or repeat running single actions containerized, you
can create a vault password file and loopback mount it to the container so that
initialization playbook does not have to ask it interactively. There is a
script called `read_vault_pass_from_clipboard.bash` under the scripts directory
for doing this.

## Using dcterm - Deployment Container TERMinal

`scripts/dcterm.bash` is a handy script that either starts a deployment container or executes a new shell in an
existing one if it already exists. You could set up an alias in your local shell to invoke it by adding a definition
in your profile. This assumes bash:

```shell script
$ grep dcterm $HOME/.bash_profile
alias dcterm='$HOME/src/gitlab.ci.csc.fi/pebbles/pebbles-deploy/scripts/dcterm.bash'
```

After setting up the alias, you can use it with

```
# starts a new deployment container, asks for vault key for the environment
$ dcterm pebbles-devel-3
...
# in another terminal, this will launch a shell in the already running container 
$ dcterm pebbles-devel-3
```

## Provisioning and configuring

In the deployment container, first check that you are on the branches that you wish to use. The branches are mounted
from your laptop's directory. Check out the branches on your laptop and double check with branch-info

```bash
branch-info
```

Then proceed with environment type specific instructions to use ansible-playbook or helm.
