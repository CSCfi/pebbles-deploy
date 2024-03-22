# stage: build ksops
FROM docker.io/library/golang:1.22-alpine as ksops-build
ARG KSOPS_COMMIT_ID=c6d9ce857ed5cfab07321bd5528c83350cc30d52

WORKDIR /go/src

RUN wget -O - https://codeload.github.com/viaduct-ai/kustomize-sops/zip/$KSOPS_COMMIT_ID | unzip /dev/stdin

WORKDIR /go/src/kustomize-sops-$KSOPS_COMMIT_ID

# separate module download to its own layer for caching
RUN go mod download -x

# build ksops and move to a fixed location to be picked up later by final layer
RUN go build -o ksops && mv ksops /go/bin/ksops

# stage: build kustomize
FROM docker.io/library/golang:1.22-alpine as kustomize-build
ARG KUSTOMIZE_COMMIT_ID=9da0cf8b4c6bc3bd6d492c66757c89df74d8f63e

WORKDIR /go/bin

RUN GOBIN=$(pwd)/ GO111MODULE=on go install sigs.k8s.io/kustomize/kustomize/v5@$KUSTOMIZE_COMMIT_ID

# stage: final image
FROM quay.io/fedora/fedora:39

LABEL maintainer="CSC Notebooks Team"
RUN dnf makecache

# Install base packages
RUN dnf install -y \
    openssh-clients \
    python python-devel pip \
    gcc openssl-devel openssl \
    jq \
    tmux less git man bash-completion \
    rsync \
    glibc-langpack-en \
    which \
    bind-utils \
    diffutils \
    findutils \
    postgresql \
    vim \
    skopeo \
    xz \
    butane \
    procps-ng \
    certbot \
    s3cmd \
    httpd-tools \
    age \
 && dnf clean all

# Install python requirements
COPY requirements.txt /root/requirements.txt
RUN pip install --no-cache-dir -r /root/requirements.txt

# Install Helm
RUN cd /tmp/ \
 && curl -LOs https://git.io/get_helm.sh \
 && chmod 700 get_helm.sh \
 && ./get_helm.sh -v v3.14.0 \
 && rm /tmp/get_helm.sh
RUN /usr/local/bin/helm completion bash > /etc/bash_completion.d/helm

# Install sops
RUN cd /tmp/  \
 && ARCH='' \
 && if [[ $(uname -m) == 'aarch64' ]]; then ARCH='arm64'; else ARCH='amd64'; fi \
 && curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.${ARCH} \
 && mv sops-v3.8.1.linux.${ARCH} /usr/local/bin/sops \
 && chmod +x /usr/local/bin/sops

# Install oc and kubectl
# Check the architecture, and download correct oc client from official mirror.
RUN cd /tmp/ \
 && ARCH='' \
 && if [[ $(uname -m) == 'aarch64' ]]; then ARCH='-arm64'; fi \
 && TARBALL=openshift-client-linux${ARCH}.tar.gz \
 && curl -LOs https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.14/${TARBALL} \
 && tar xvfz ${TARBALL} \
 && install oc /usr/local/bin/oc \
 && install kubectl /usr/local/bin/kubectl \
 && rm ${TARBALL} oc kubectl README.md

# Create completion for oc
RUN /usr/local/bin/oc completion bash > /etc/bash_completion.d/oc

# Copy kustomize binary into place
COPY --from=kustomize-build /go/bin/kustomize /usr/local/bin/kustomize

# Copy ksops binary into place
COPY --from=ksops-build /go/bin/ksops /usr/local/bin/ksops

# Choose an arbitrary GID so that vault password can be made group readable when mounted as a volume
# in a reasonably safe way
RUN groupadd -g 29295 deployer
RUN useradd -u 29295 -g deployer -d /opt/deployment deployer

# make home directory writable and accessible under openshift
RUN chgrp -R root /opt/deployment \
 && find /opt/deployment -type d -exec chmod g+rwx,o+rx {} \; \
 && find /opt/deployment -type f -exec chmod g+rw {} \;

# make certbot directory writable
RUN mkdir -p /etc/letsencrypt && chown -R 29295:0 /etc/letsencrypt

# set pebbles-deploy ansible_dc.cfg as the default
# when all deployments use pebbles-deploy, this can be unified to ansible.cfg
ENV ANSIBLE_CONFIG=/opt/deployment/pebbles-deploy/ansible_dc.cfg

# VIM is installed, so designate that as the default
ENV EDITOR=vim

# user content from this point on
USER 29295

WORKDIR /opt/deployment
ENV HOME=/opt/deployment

# bake Ansible roles in the image to reduce runtime dependencies
RUN mkdir -p /opt/deployment/galaxy-roles/{k3s,nfs} \
 && curl https://a3s.fi/notebooks-devel-public/ansible-role-k3s-f0d5728956.tar.gz \
  | tar xz -C /opt/deployment/galaxy-roles/k3s \
 && curl -L https://github.com/geerlingguy/ansible-role-nfs/archive/11e9802153ffe19709e1fd3d1e49beb0d641d760.tar.gz \
  | tar xz --strip-components=1 -C /opt/deployment/galaxy-roles/nfs

RUN ansible-galaxy install openstack \
 && ansible-galaxy collection install prometheus.prometheus

# Install Helm-Secrets plugin
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version v4.5.1

# copy scripts
COPY bin bin
# copy config
COPY bashrc .bashrc
COPY gitconfig .gitconfig

CMD /bin/bash
