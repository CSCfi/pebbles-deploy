# OpenShift installation instructions Pebbles release-5

This document contains instructions for installing Pebbles on OpenShift.

# Bootstrap

## Prerequisites

The installation environment runs in purpose-built Docker container called "deployment container".
See [Using_deployment_container.md](Using_deployment_container.md) for prerequisites,
checking out the repositories and launching a deployment container.

# Development installation

## Building images from local sources

There are several build commands for building all images or a single image. You can list them with tab-completion:

```
pebbles-devel-3 ~ () > build-image-[TAB]
build-image-all                     build-image-from-project-src        build-image-pebbles-deployer
build-image-all-parallel            build-image-logstash                build-image-pebbles-frontend
build-image-filebeat                build-image-pebbles
build-image-from-container-src      build-image-pebbles-admin-frontend
```

Usually `build-image-all-parallel` is the best choice for the first build. After the builds have finished, you can
list the images (`imagestreams` in OpenShift talk).

```shell script
build-image-all-parallel
oc get imagestream
```

## Helm installö

Once the images have been built, install Pebbles with

```shell script
pb-helm-upgrade
```

At this point the database is empty, so the system does not actually work. To initialize database content and
set worker password, run:

```shell script
cde
pb-initialize-database devel-users.sops.yaml initial-data.yaml
```

After this point, the system should be up and running happily.

# Development upgrades

## Upgrade images

To test new code in existing deployment, you can

* check out the desired combination of branches in pebbles, pebbles-frontend, pebbles-deploy and pebbles-environments
* build the image(s) using instructions above
* restart the relevant services

For example, here we build a new frontend image, wait for the build to finish with `--follow` and restart the frontend
pods.

```shell script
build-image-pebbles-frontend --follow && restart-pebbles frontend
```

## Upgrade deployment

To change the Helm deployment, you can use a shortcut to reflect changes in pebbles-environments and
Helm charts by upgrading Helm deployment by:

```shell script
pb-helm-upgrade
```

# Notes

## Aliases in deployment container

All aliases in deployment container are defined in `container-src/pebbles-deployer/deploy_functions.bash`. Take a look
at the definitions to see what they are actually doing and copy and customize to need.
