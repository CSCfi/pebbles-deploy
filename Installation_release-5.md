# Development environment installation for Pebbles release-5

This document helps you get going with Pebbles development by showing how to deploy Pebbles on a local Kubernetes
running on your laptop (MacOS or Linux). 

For MacOS, install Docker Desktop and enable Kubernetes.

For Linux, install Minikube.

# Bootstrap

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
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-0.32.0/deploy/static/provider/cloud/deploy.yaml
```

And here is how you enable it on minikube:

```shell script
minikube addons enable ingress
```

## OpenShift client

Mac:

```shell script
brew install openshift-cli
```

Linux: 

see https://github.com/openshift/origin/releases/tag/v3.11.0

## Repositories

Check out repositories checked out in golang style directory structure

```shell script
mkdir -p ~/src/gitlab.ci.csc.fi/pebbles/
cd  ~/src/gitlab.ci.csc.fi/pebbles/
git clone https://gitlab.ci.csc.fi/pebbles/pebbles
git clone https://gitlab.ci.csc.fi/pebbles/pebbles-deploy
git clone https://gitlab.ci.csc.fi/pebbles/pebbles-environments
git clone https://gitlab.ci.csc.fi/pebbles/pebbles-frontend
```

## Install tools

### Helm 3

Linux:

```shell script
curl -LO https://git.io/get_helm.sh
bash ./get_helm.sh -v v3.0.3
```

Mac:
```shell script
brew install helm
```

### s2i (optional)
On Linux, to install s2i

```shell script
cd /tmp
wget https://github.com/openshift/source-to-image/releases/download/v1.1.14/source-to-image-v1.1.14-874754de-linux-amd64.tar.gz
tar xvf source-to-image-v1.1.14-874754de-linux-amd64.tar.gz
sudo install s2i /usr/local/bin/
cd
```

On a Mac, you can use

```shell script
brew install source-to-image
```


# Building

The idea here is to build images locally so that they are available to the local Kubernetes without
having to pull them from any registry.

On Linux + minikube, you will need change the docker context to point to the docker inside minikube VM 
(sudo -i if needed):

```shell script
eval $(minikube docker-env)
```

## Building pebbles image

Build using pebbles dockerfile:

```shell script
pushd ~/src/gitlab.ci.csc.fi/pebbles/pebbles && docker build --tag pebbles:latest . --file=deployment/pebbles-s2i.Dockerfile && popd
```

Alternative: You can also use `s2i` to build the image

```shell script
pushd ~/src/gitlab.ci.csc.fi/pebbles/pebbles && s2i build . --copy -e UPGRADE_PIP_TO_LATEST=1 centos/python-38-centos7 pebbles && popd
```

## Building pebbles-frontend image

This is taken from pebbles-frontend/deployment/building.md "Build with old AngularJS code included":

```shell script
# change to project root directory
cd ~/src/gitlab.ci.csc.fi/pebbles/pebbles-frontend/

# install dependencies
npm install

# build the application (production build here)
npm run-script build:prod

# copy AngularJS code from Pebbles-repo, assuming it is cloned as sibling directory
cp -r ../pebbles/pebbles/static/index.html dist/pebbles-frontend/admin.html
cp -r ../pebbles/pebbles/static/{img,js,css,fonts,partials} dist/pebbles-frontend/.

# create runtime image by copying the compiled application in it
docker build . -t pebbles-frontend:latest -f deployment/Dockerfile.runtime
```

# Deploying with Helm

## Configuration for minimal local deployment
Next we create a configuration file for local deployment for Helm. 
Create local_values/local_k8s.yaml file with the following contents:

```yaml
workerImagePullPolicy: IfNotPresent
apiImagePullPolicy: IfNotPresent
frontendImagePullPolicy: IfNotPresent
#mountHostSrc: /CHANGE_ME/src/gitlab.ci.csc.fi/pebbles/pebbles
#useSourceVolume: true
apiDevelopmentMode: true
apiDisableCORS: true
#remoteDebugServerWorker: host.docker.internal
#remoteDebugServerApi: host.docker.internal
ingressHost: localhost
databaseVolumeSize: 1Gi

deployCentralLogging: false

backupEnabled: false

oauth2LoginEnabled: false
oauth2ProxySecret: ""
oauth2ProxyClientId: ""
oauth2ProxyClientSecret: ""

clusterConfig: |
  clusters:
    - name: local_kubernetes
      driver: KubernetesLocalDriver
```

Note the image pull policies that make it possible to use locally build images already present in Docker.

## Deploy Pebbles

```shell script
cd ~/src/gitlab.ci.csc.fi/pebbles/pebbles-deploy

# create namespace if not present
oc get namespace pebbles || oc create namespace pebbles

# deploy with helm
helm install pebbles helm_charts/pebbles -f local_values/local_k8s.yaml --set overrideSecret=1

# wait until api pod is running
while ! oc get pod -l name=api | egrep '1/1|2/2' | grep 'Running'; do echo 'Waiting for api pod'; sleep 5; done

# initialize system with either 
# a) development data that sets up a basic set of users and environments
# NOTE: due to interactive prompt, paste these ONE LINE at the time
oc rsh $(oc get pod -o name -l name=api) bash -c 'python manage.py create_database'
oc rsh $(oc get pod -o name -l name=api) bash -c 'python manage.py load_test_data /dev/stdin' < ../pebbles/devel_dataset.yaml
oc rsh $(oc get pod -o name -l name=api) bash -c 'python manage.py reset_worker_password'

# b) just bare minimum
oc rsh $(oc get pod -o name -l name=api) python manage.py initialize_system -e admin@example.org -p admin
```

You can watch the progress with `oc get pods`, or run `watch oc get pods` in a different terminal window.

After the initialization, you can try connecting to http://localhost and log in with the admin credentials you gave
above.

### Notes on Minikube/Linux

If ingress is not listening on localhost/127.0.0.1, the default application domain will not work for accessing the instances.
You can update the helm installation by

```shell script
helm upgrade pebbles deployment/helm_charts/pebbles --set instanceAppDomain=YOUR-MINIKUBE-IP-WITH-DASHES.nip.io
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
oc rsh $(oc get pod -o name -l name=db) bash -c 'psql -d pebbles'
```

## Pycharm remote debugging

Rebuild pebbles image with pycharm-dev-tools, they are commented out by default in requirements.txt. 

Uncomment and modify your local_values/local_k8s.yaml, key 'remoteDebugServerApi'. Note that you need to adapt the host
name, the example works on MacOS. 

Then update your deployment:

```shell script
helm upgrade pebbles helm_charts/pebbles -f local_values/local_k8s.yaml
```

Your API will now contact pycharm remote debugger at startup, so it won't start at first. Set up 
`Python Remote Debugging` configuration in PyCharm:
 
 * set the port to 12345
 * set the source code mappings to YOUR_HOME_DIRECTORY_HERE/src/gitlab.ci.csc.fi/pebbles/pebbles=/opt/app-root/src

Start debug, and the API container should connect and start.

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

Delete the local installation including data, and the shared secrets.

```shell script
oc delete namespace pebbles
```
