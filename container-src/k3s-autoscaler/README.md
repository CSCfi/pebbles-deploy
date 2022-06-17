# Autoscaler for K3s on OpenStack

This is a simple autoscaler for K3s on OpenStack. It watches the workloads on a K3s cluster and scales the cluster up
and down by provisioning and deleting node VMs in OpenStack. Nodes are supposed to be configured with Ignition/Butane -
in practice Fedora CoreOS fits the bill.

# Configuration

Paths to following files are supposed to be set as environment variables. 

## AUTOSCALER_CONFIG_FILE

Path to main config file. Example:

```
clusterName: dev-cluster
flavor: io.70GB
image: fedora-coreos-36.20220522.3.0-openstack.x86_64.qcow2

freeMemoryTarget: 9 GiB
maximumNumberOfNodes: 1
oldNodeAgeLimitHours: 72

butaneBinary: /usr/bin/butane
butaneConfigTemplate: k3s-node.butane.j2
butaneConfigData:
  master_vm_ip: 192.168.1.1
  k3s_version: v1.23.6+k3s1
  k3s_node_token: Kxxxxx::server:1234567890
```

## OPENSTACK_CREDENTIALS_FILE

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

## KUBECONFIG_FILE

Path to standard kubeconfig file that has admin access to the target cluster.

