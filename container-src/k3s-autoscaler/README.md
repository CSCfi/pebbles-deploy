# Autoscaler for K3s on OpenStack

This is a simple autoscaler for K3s on OpenStack. It watches the workloads on a K3s cluster and scales the cluster up
and down by provisioning and deleting node VMs in OpenStack. Nodes are supposed to be configured with Ignition/Butane -
in practice Fedora CoreOS fits the bill.

## Overview

Autoscaler will run in a loop, sleep for a while and then check if any actions need to be taken. Before each update
cycle the current state of pods and nodes in K3s cluster is queried. Autoscaler will not store state anywhere, it will
rely purely on the current K3s state.

### Actions, in order of priority:

1) Scale up
   If free memory is less than configured target, spawn a new node VM. Node is initially tainted so no workloads can
   start before autoscaler removes that taint. This is to avoid a race condition when autoscaler gives up waiting for 
   the node and deletes it while the node just becomes ready and starts accepting workloads

2) Mark old node as unschedulable to start draining it
   If there is enough capacity, start draining a node that is older than oldNodeAgeLimitHours 

3) Remove empty unschedulable node
   Remove drained node from k3s and delete the VM

4) Warm up image caches on nodes
   
Only one action is taken during a single update cycle, e.g. warming image caches only takes place if there is nothing
else to do.

## Configuration

Paths to following files are supposed to be set as environment variables.

### AUTOSCALER_CONFIG_FILE

Path to main config file. Example:

```
clusterName: dev-cluster
flavor: io.70GB
image: fedora-coreos-36.20220522.3.0-openstack.x86_64.qcow2

freeMemoryTarget: 9 GiB
minimumFreeNodeMemory: 4 GiB
maximumNumberOfNodes: 1
oldNodeAgeLimitHours: 72
imagePullerIgnorelist:
- docker.io/foo

butaneBinary: /usr/bin/butane
butaneConfigTemplate: k3s-node.butane.j2
butaneConfigData:
  master_vm_ip: 192.168.1.1
  k3s_version: v1.23.6+k3s1
  k3s_node_token: Kxxxxx::server:1234567890
```

### OPENSTACK_CREDENTIALS_FILE

Path to YAML file with OpenStack credentials. Example:

```
OS_AUTH_URL: "https://pouta.csc.fi:5001/v3"
OS_IDENTITY_API_VERSION: 3
OS_USERNAME: "user"
OS_PASSWORD: "fairlys3cretpassw0rd?not"
OS_USER_DOMAIN_NAME: "default"
OS_TENANT_ID: "12345"
OS_TENANT_NAME: "12345"
OS_REGION: "nova"
```

### KUBECONFIG_FILE

Path to standard kubeconfig file that has admin access to the target cluster.
