FROM centos:centos8.3.2011

LABEL maintainer="CSC Notebooks Team"

# Install base packages
RUN dnf install -y \
        openssh-clients \
        python36-devel python3-pip \
        gcc openssl-devel openssl \
        jq \
        tmux less git man bash-completion \
        rsync \
        glibc-langpack-en \
        which \
        bind-utils \
        diffutils \
        epel-release \
        postgresql \
 && dnf clean all

# Add s3cmd from EPEL for dealing with Allas object storage with S3 credentials
RUN dnf install -y \
        s3cmd \
 && dnf clean all

# Make python3 as the python for '#!/usr/bin/env python'
RUN alternatives --set python /usr/bin/python3

# Install python requirements
COPY requirements.txt /root/requirements.txt
RUN pip3 install --no-cache-dir -U pip
RUN pip3 install --no-cache-dir -U setuptools
RUN pip3 install --no-cache-dir -r /root/requirements.txt

# Install helm
RUN cd /tmp/ \
 && curl -LOs https://git.io/get_helm.sh \
 && chmod 700 get_helm.sh \
 && ./get_helm.sh -v v3.2.4 \
 && rm /tmp/get_helm.sh
RUN /usr/local/bin/helm completion bash > /etc/bash_completion.d/helm

# Install oc and kubectl
# Temporarily use oc binary uploaded to Allas and extracted with:
# oc adm release extract --command=oc --command-os=linux registry.svc.ci.openshift.org/origin/release:4.4.0-0.okd-2020-03-24-091256
# Once OKD 4 client binary releases are out, we can switch to those
RUN cd /tmp/ \
 && curl -LOs https://a3s.fi/notebooks-devel-public/oc-4.4.0-0.okd-2020-03-24-091256 \
 && install oc-4.4.0-0.okd-2020-03-24-091256 /usr/local/bin/oc \
 && install oc-4.4.0-0.okd-2020-03-24-091256 /usr/local/bin/kubectl \
 && rm /tmp/oc-4.4.0-0.okd-2020-03-24-091256
RUN /usr/local/bin/oc completion bash > /etc/bash_completion.d/oc

# Choose an arbitrary GID so that vault password can be made group readable when mounted as a volume
# in a reasonably safe way
RUN groupadd -g 29295 deployer
RUN useradd -u 29295 -g deployer -d /opt/deployment deployer

# make home directory writable and accessible under openshift
RUN chgrp -R root /opt/deployment \
 && find /opt/deployment -type d -exec chmod g+rwx,o+rx {} \; \
 && find /opt/deployment -type f -exec chmod g+rw {} \;

# set pebbles-deploy ansible_dc.cfg as the default
# when all deployments use pebbles-deploy, this can be unified to ansible.cfg
ENV ANSIBLE_CONFIG=/opt/deployment/pebbles-deploy/ansible_dc.cfg

USER 29295

WORKDIR /opt/deployment
ENV HOME=/opt/deployment

COPY init_env.bash init_env.bash
COPY bashrc .bashrc
COPY deploy_functions.bash deploy_functions.bash

# bake roles in the image to reduce dependencies
RUN mkdir -p /opt/deployment/galaxy-roles/{k3s,nfs} \
 && curl https://a3s.fi/notebooks-devel-public/ansible-role-k3s-38aeebe.tar.gz \
  | tar xz -C /opt/deployment/galaxy-roles/k3s \
 && curl -L https://github.com/geerlingguy/ansible-role-nfs/archive/11e9802153ffe19709e1fd3d1e49beb0d641d760.tar.gz \
  | tar xz --strip-components=1 -C /opt/deployment/galaxy-roles/nfs

CMD /bin/bash
