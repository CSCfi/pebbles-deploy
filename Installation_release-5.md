# Development environment installation for Pebbles release-5

This document helps you get going with Pebbles development by showing how to deploy Pebbles on a local Kubernetes
running on your laptop (MacOS or Linux). 

For MacOS, install Docker Desktop and enable Kubernetes.

For Linux, install Minikube.

# Bootstrap

## Local Kubernetes
List the contexts for kubernetes

```bash
kubectl config get-contexts
```

Switch context

```bash
kubectl config use-context docker-for-desktop
```

Here is how to deploy nginx ingress controller for docker for mac

https://kubernetes.github.io/ingress-nginx/deploy/

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-0.32.0/deploy/static/provider/cloud/deploy.yaml
```

And here is how you enable it on minikube:

```bash
minikube addons enable ingress
```

## OpenShift client

Mac:

```bash
brew install openshift-cli
```

Linux: 

see https://github.com/openshift/origin/releases/tag/v3.11.0

## Repositories

Check out repositories checked out in golang style directory structure

```bash
mkdir -p ~/src/gitlab.ci.csc.fi/pebbles/
cd  ~/src/gitlab.ci.csc.fi/pebbles/
git clone https://gitlab.ci.csc.fi/pebbles/pebbles
git clone https://gitlab.ci.csc.fi/pebbles/pebbles-deploy
git clone https://gitlab.ci.csc.fi/pebbles/pebbles-environments
```

## Install tools

### s2i
On Linux, to install s2i

```bash
cd /tmp
wget https://github.com/openshift/source-to-image/releases/download/v1.1.14/source-to-image-v1.1.14-874754de-linux-amd64.tar.gz
tar xvf source-to-image-v1.1.14-874754de-linux-amd64.tar.gz
sudo install s2i /usr/local/bin/
cd
```

On a Mac, you can use

```bash
brew install source-to-image
```

### Helm 3

Linux:

```bash
curl -LO https://git.io/get_helm.sh
bash ./get_helm.sh -v v3.0.3
```

Mac:
```bash
brew install helm
```


# Building

## Building pebbles image

Check out release-5:

```bash
cd  ~/src/gitlab.ci.csc.fi/pebbles/pebbles
git checkout release-5
```

On Linux + minikube, you can change the docker context to point to the docker inside minikube VM 
(sudo -i if needed):

```bash
eval $(minikube docker-env)
```

Actual build:

```bash
pushd ~/src/gitlab.ci.csc.fi/pebbles/pebbles && s2i build . --copy -e UPGRADE_PIP_TO_LATEST=1 centos/python-38-centos7 pebbles && popd
```


# Deploying with Helm

## Configuration for minimal local deployment
Next we create a configuration file for local deployment for Helm. 
Create local_values/local_k8s.yaml file with the following contents:

```yaml
workerImagePullPolicy: IfNotPresent
apiImagePullPolicy: IfNotPresent
#mountHostSrc: /CHANGE_ME/src/gitlab.ci.csc.fi/pebbles/pebbles
#useSourceVolume: true
apiDevelopmentMode: true
apiDisableCORS: true
#remoteDebugServerWorker: host.docker.internal
#remoteDebugServerApi: host.docker.internal
ingressHost: localhost
databaseVolumeSize: 1Gi

deployCentralLogging: false

oauth2LoginEnabled: false
oauth2ProxySecret: ""
oauth2ProxyClientId: ""
oauth2ProxyClientSecret: ""

clusterConfig: |
  clusters:
    - name: local_kubernetes
      driver: KubernetesLocalDriver
```

## Deploy Pebbles

```bash
cd ~/src/gitlab.ci.csc.fi/pebbles/pebbles-deploy
helm install pebbles helm_charts/pebbles -f local_values/local_k8s.yaml --set overrideSecret=1

# check that api pod is Running 
oc get pods

# initialize system
oc rsh $(oc get pod -o name -l name=api) python manage.py initialize_system -e admin@example.org -p admin
```

You can watch the progress with `oc get pods`, or run `watch oc get pods` in a different terminal window.

After the initialization, you can try connecting to http://localhost and log in with the admin credentials you gave
above.

### Notes on Minikube/Linux

If ingress is not listening on localhost/127.0.0.1, the default application domain will not work for accessing the instances.
You can update the helm installation by

```bash
helm upgrade pebbles deployment/helm_charts/pebbles --set instanceAppDomain=YOUR-MINIKUBE-IP-WITH-DASHES.nip.io
```

Also, add your minikube IP to /etc/hosts as an alias for the web server/API.

# Hints for development

## Mount the source code to api and worker containers

Uncomment and modify your local_values/local_k8s.yaml, key 'mountHostSrc'. Note that you need to adapt the path based
on which folder your source is in. It also varies by platform, in Docker for Mac it would be 
/Users/username/src/gitlab.ci.csc.fi/...

Then update your deployment:

```bash
helm upgrade pebbles helm_charts/pebbles -f local_values/local_k8s.yaml
```

## Open database shell
```bash
oc rsh $(oc get pod -o name -l name=db) bash -c 'psql -d pebbles'
```

## Pycharm remote debugging

Rebuild pebbles image with pycharm-dev-tools, they are commented out by default in requirements.txt. 

Uncomment and modify your local_values/local_k8s.yaml, key 'remoteDebugServerApi'. Note that you need to adapt the host
name, the example works on MacOS. 

Then update your deployment:

```bash
helm upgrade pebbles helm_charts/pebbles -f local_values/local_k8s.yaml
```

Your API will now contact pycharm remote debugger at startup, so it won't start at first. Set up 
`Python Remote Debugging` configuration in PyCharm:
 
 * set the port to 12345
 * set the source code mappings to YOUR_HOME_DIRECTORY_HERE/src/gitlab.ci.csc.fi/pebbles/pebbles=/opt/app-root/src

Start debug, and the API container should connect and start.
