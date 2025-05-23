# Development environment installation for Pebbles release-5

This document helps you get going with Pebbles development by showing how to deploy Pebbles on a local Kubernetes
running on your laptop (MacOS or Linux). Note that these only work within CSC networks for CSC employees.

For MacOS, install Podman and Kind. You can also use Docker Desktop and enable Kubernetes.

For Linux, install Minikube.

# Bootstrap

## Podman on Mac

Prepare your shell enviroment. In .zshrc (or equivalent), add

```shell script
# podman settings
export DOCKER_EXECUTABLE=podman
export KIND_EXPERIMENTAL_PROVIDER=podman
```

Take a fresh shell, and install podman, kind and pebbles.

```shell script
# first install podman and kind
brew install podman kind

# then initialize the podman VM with 3GiB of RAM
podman machine init --memory 3072 --rootful

# start the machine
podman machine start

# enable memory compression (swapping to a compressed ramdisk)
podman machine ssh $HOME/src/gitlab.ci.csc.fi/pebbles/pebbles-deploy/scripts/podman_enable_zram_swap.bash

# deploy Kind with NGINX ingress controller
$HOME/src/gitlab.ci.csc.fi/pebbles/pebbles-deploy/scripts/podman_kind.bash
```

## Local Kubernetes

List the contexts for kubernetes

```shell script
kubectl config get-contexts
```

Switch context to the relevant one, on Docker Desktop for Mac 2.4.0.0 for example:

```shell script
kubectl config use-context docker-desktop
```

Here is how to deploy nginx ingress controller for docker for mac

https://kubernetes.github.io/ingress-nginx/deploy/

```shell script
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
```

If you encounter problems with accessing pebbles on localhost, restarting docker/laptop after installation may help.

Here is how you enable it on minikube:

```shell script
minikube addons enable ingress
```

## OpenShift client

Mac:

```shell script
brew install openshift-cli
```

Linux:

See https://github.com/openshift/okd/releases

## Repositories

Check out repositories checked out in golang style directory structure.

```shell script
mkdir -p ~/src/gitlab.ci.csc.fi/pebbles/
cd  ~/src/gitlab.ci.csc.fi/pebbles/
git clone ssh://git@gitlab.ci.csc.fi:10022/pebbles/pebbles.git
git clone ssh://git@gitlab.ci.csc.fi:10022/pebbles/pebbles-frontend.git
git clone ssh://git@gitlab.ci.csc.fi:10022/pebbles/pebbles-admin-frontend.git
git clone ssh://git@gitlab.ci.csc.fi:10022/pebbles/pebbles-deploy.git
git clone ssh://git@gitlab.ci.csc.fi:10022/pebbles/pebbles-environments.git
```

## Install tools

### Helm 3

Linux:

```shell script
curl -LO https://git.io/get_helm.sh
bash ./get_helm.sh -v v3.15.0
```

Mac:

```shell script
brew install helm
```

# Building

The idea here is to build images locally so that they are available to the local Kubernetes without
having to pull them from any registry.

On Linux + minikube, you will need change the docker context to point to the docker inside minikube VM
(sudo -i if needed):

```shell script
eval $(minikube docker-env)
```

Build images using podman:

```shell script
cd ~/src/gitlab.ci.csc.fi/pebbles
pushd pebbles; podman build --tag pebbles:latest . --file=deployment/pebbles.Dockerfile; popd
pushd pebbles-frontend; podman build . -t pebbles-frontend:latest -f deployment/Dockerfile.multi-stage; popd
pushd pebbles-admin-frontend; podman build . -t pebbles-admin-frontend:latest -f deployment/Dockerfile.multi-stage; popd
```

If using podman/kind, load images to kind (kind runs in podman, but it does not share images. It needs its own copy):

```shell script
podman save localhost/pebbles:latest | kind load image-archive /dev/stdin
podman save localhost/pebbles-frontend:latest | kind load image-archive /dev/stdin
podman save localhost/pebbles-admin-frontend:latest | kind load image-archive /dev/stdin
```

# Deploying with Helm

## Configuration for minimal local deployment

Next we create a configuration file for local deployment for Helm.
Create local_values/local_k8s.yaml file with the following contents:

```yaml
dbImage: quay.io/fedora/postgresql-15:latest
# enable localhost prefix for podman/kind
#imagePrefix: localhost/

workerImagePullPolicy: IfNotPresent
apiImagePullPolicy: IfNotPresent
frontendImagePullPolicy: IfNotPresent
adminFrontendImagePullPolicy: IfNotPresent
adminFrontendEnabled: true
#mountHostSrc: /CHANGE_ME/src/gitlab.ci.csc.fi/pebbles/pebbles
#useSourceVolume: true

apiDevelopmentMode: true
apiDisableCORS: true

#remoteDebugServerWorker: host.containers.internal
#remoteDebugServerApi: host.containers.internal
ingressHost: localhost
ingressClass: nginx

# Enable this on podman/kind to allow ingress traffic 
#networkPolicyDefaultIngressNamespaces: ["ingress-nginx"]

databaseVolumeSize: 1Gi

deployCentralLogging: false

backupEnabled: false

oauth2LoginEnabled: false
oauth2ProxyClientId: ""
oauth2ProxyClientSecret: ""

clusterConfig: |
  clusters:
    - name: local_kubernetes
      driver: KubernetesLocalDriver
      ingressClass: nginx

```

Note the image pull policies that make it possible to use locally built images already present in container runtime.

## Deploy Pebbles

Deploy with Helm

```shell script
cd ~/src/gitlab.ci.csc.fi/pebbles/pebbles-deploy

echo "deploy with helm"
helm upgrade -i pebbles helm_charts/pebbles -f local_values/local_k8s.yaml

echo "wait until api pod is running"
while ! oc get pod -l name=api | egrep '1/1|2/2' | grep 'Running'; do echo 'Waiting for api pod'; sleep 5; done
```

Initialize system with either

a) development data that sets up a basic set of users and environments

```shell script
oc rsh deployment/api bash -c 'flask db upgrade' && \
oc rsh deployment/api bash -c 'python manage.py load_data /dev/stdin' < ../pebbles/devel_dataset.yaml && \
oc rsh deployment/api bash -c 'python manage.py reset_worker_password'

```

b) just bare minimum

```shell script
oc rsh deployment/api bash -c 'flask db upgrade' && \
oc rsh deployment/api bash -c 'python manage.py initialize_system -e admin@example.org -p admin'
```

You can watch the progress with `oc get pods`, or run `watch oc get pods` in a different terminal window.

After the initialization, you can try connecting to http://localhost and log in with the admin credentials from
`../pebbles/devel_dataset.yaml` or with what you used in `manage.py initialize_system` above.

### Notes on Minikube/Linux

If ingress is not listening on localhost/127.0.0.1, the default application domain will not work for accessing the
instances.
You can update the helm installation by

```shell script
helm upgrade pebbles helm_charts/pebbles \
  -f local_values/local_k8s.yaml \
  --set instanceAppDomain=YOUR-MINIKUBE-IP-WITH-DASHES.nip.io
```

Also, add your minikube IP to /etc/hosts as an alias for the web server/API.

# Hints for development

## Mount the source code to api and worker containers

Uncomment and modify your local_values/local_k8s.yaml, key 'mountHostSrc'. Note that you need to adapt the path based
on which folder your source is in. It also varies by platform, in Docker for Mac it would be
/Users/username/src/gitlab.ci.csc.fi/...

Then update your deployment:

```shell script
helm upgrade pebbles helm_charts/pebbles -f local_values/local_k8s.yaml
```

## Open database shell

```shell script
oc rsh deployment/db bash -c 'psql -d pebbles'
```

## Pycharm remote debugging

Rebuilding pebbles image for remote debugging:

```shell script
pushd ~/src/gitlab.ci.csc.fi/pebbles/pebbles
podman build --tag pebbles:latest . --file=deployment/pebbles.Dockerfile --build-arg EXTRA_PIP_PACKAGES=pydevd-pycharm
popd
```

If using Kind, update the image on the node
```shell script
podman save localhost/pebbles:latest | kind load image-archive /dev/stdin
```

Upgrade helm:

- Uncomment and modify your local_values/local_k8s.yaml, key `remoteDebugServerApi`. Note that you need to adapt the
  host name, the example works at least with Podman on Mac.

- Then update your deployment:

```shell script
helm upgrade pebbles helm_charts/pebbles -f local_values/local_k8s.yaml
```

Set up pycharm debugger:

Your API will now contact pycharm remote debugger at startup, so it won't start at first. Set up
`Python Remote Debugging` configuration in PyCharm.

* set the port to 12345
* set the source code mappings to YOUR_HOME_DIRECTORY_HERE/src/gitlab.ci.csc.fi/pebbles/pebbles=/opt/app-root/src

To start debug, delete API pod to restart it and the API container should connect and start.

# Adding cluster resources for running the Environments

## Example: remote K3s

If you want to add a remote K3s to your installation, you need to add the corresponding `.kube/config` file in
Helm values.

In this example, we add a `clusterKubeconfig` entry with a single development cluster deployed from the deployment
container as a `k3s` type deployment. You can obtain the configuration by launching a deployment container for the
respective environment ("notebooks-dev-2-k3s" in this case) and copying the contents of `/opt/deployment/.kube/config`.

```yaml
clusterConfig: |
  clusters:
    ...
    - name: notebooks-dev-2-k3s
      driver: KubernetesRemoteDriver
      url: https://REDACTED:6443
      appDomain: REDACTED.nip.io

clusterKubeconfig: |
  apiVersion: v1
  clusters:
    - name: notebooks-dev-2-k3s
      cluster:
        certificate-authority-data: REDACTED
        server: https://REDACTED:6443
  contexts:
    - context:
        cluster: notebooks-dev-2-k3s
        user: notebooks-dev-2-k3s
      name: notebooks-dev-2-k3s
  current-context: notebooks-dev-2-k3s
  kind: Config
  preferences: { }
  users:
    - name: notebooks-dev-2-k3s
      user:
        client-certificate-data: REDACTED
        client-key-data: REDACTED
```

In `clusterKubeconfig`, you need to change the cluster name, context name and user name to match the cluster name in
`clusterConfig`.

# Deleting the deployment

Delete the local installation including data and the shared secret.

```shell script
helm delete pebbles; oc delete secret pebbles
```
