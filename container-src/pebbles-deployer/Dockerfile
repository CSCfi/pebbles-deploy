FROM quay.io/fedora/fedora:44
ARG PEBBLES_DEPLOY_SRC="https://github.com/CSCfi/pebbles-deploy.git"
ARG PEBBLES_DEPLOY_REF="main"

# Set by BuildKit, podman and buildah to amd64 or arm64; used to pick release artifacts below
ARG TARGETARCH
RUN case "${TARGETARCH}" in amd64|arm64) ;; *) echo "TARGETARCH must be amd64 or arm64, got '${TARGETARCH}'"; exit 1;; esac

LABEL maintainer="CSC Noppe Team"

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
    vim nano \
    skopeo \
    xz \
    butane \
    procps-ng \
    certbot \
    s3cmd \
    httpd-tools \
    age \
    k9s \
    bat \
    yq \
 && dnf clean all

# Install python requirements
COPY requirements.txt /root/requirements.txt
RUN pip install --no-cache-dir --require-hashes -r /root/requirements.txt

# Install Helm
ARG HELM_VERSION=v3.22.0
ARG HELM_SHA256_amd64=1e4ab49e429626cf6c6958d914248b78c9730803c2751b87627e171dc800e7bb
ARG HELM_SHA256_arm64=f14e804dfee240f55525b667488fe9adca349e63e00c9af634c0beb1421ac310
RUN cd /tmp/ \
 && SHA256_VAR=HELM_SHA256_${TARGETARCH} \
 && TARBALL=helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz \
 && curl -fsSLO https://get.helm.sh/${TARBALL} \
 && echo "${!SHA256_VAR}  ${TARBALL}" | sha256sum -c - \
 && tar xfz ${TARBALL} \
 && install linux-${TARGETARCH}/helm /usr/local/bin/helm \
 && rm -rf ${TARBALL} linux-${TARGETARCH}
RUN /usr/local/bin/helm completion bash > /etc/bash_completion.d/helm

# Install sops
ARG SOPS_VERSION=v3.13.3
ARG SOPS_SHA256_amd64=e5bec3346a873ae91d871550f3e698c1aad962aff462a080e40f25fde17fef6b
ARG SOPS_SHA256_arm64=53b0abacd38ef1b12a66d6c100956691b9cefce018d91f81e73ddf7438b94d77
RUN cd /tmp/  \
 && SHA256_VAR=SOPS_SHA256_${TARGETARCH} \
 && BINARY=sops-${SOPS_VERSION}.linux.${TARGETARCH} \
 && curl -fsSLO https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/${BINARY} \
 && echo "${!SHA256_VAR}  ${BINARY}" | sha256sum -c - \
 && mv ${BINARY} /usr/local/bin/sops \
 && chmod +x /usr/local/bin/sops

# Install oc and kubectl
# Pinned to an explicit release, since the checksums below do not apply to the moving 'stable-4.19'
ARG OC_VERSION=4.19.45
ARG OC_SHA256_amd64=7d183e58997c6e63c4ba944c7903a96c899426300c417a5264c617345160f7c3
ARG OC_SHA256_arm64=1051c8b1ab01d8c953d8915eb4e550ee62353e0131a23f4ea9ac0caecae76f45
RUN cd /tmp/ \
 && SHA256_VAR=OC_SHA256_${TARGETARCH} \
 && if [[ ${TARGETARCH} == 'amd64' ]]; then ARCH=''; else ARCH="-${TARGETARCH}"; fi \
 && TARBALL=openshift-client-linux${ARCH}-${OC_VERSION}.tar.gz \
 && curl -fsSLO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/${TARBALL} \
 && echo "${!SHA256_VAR}  ${TARBALL}" | sha256sum -c - \
 && tar xfz ${TARBALL} oc kubectl \
 && install oc /usr/local/bin/oc \
 && install kubectl /usr/local/bin/kubectl \
 && rm -f ${TARBALL} oc kubectl

# Create completion for oc
RUN /usr/local/bin/oc completion bash > /etc/bash_completion.d/oc

# Install kustomize
ARG KUSTOMIZE_VERSION=v5.8.1
ARG KUSTOMIZE_SHA256_amd64=029a7f0f4e1932c52a0476cf02a0fd855c0bb85694b82c338fc648dcb53a819d
ARG KUSTOMIZE_SHA256_arm64=0953ea3e476f66d6ddfcd911d750f5167b9365aa9491b2326398e289fef2c142
RUN cd /tmp/ \
 && SHA256_VAR=KUSTOMIZE_SHA256_${TARGETARCH} \
 && TARBALL=kustomize_${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz \
 && curl -fsSLO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/${TARBALL} \
 && echo "${!SHA256_VAR}  ${TARBALL}" | sha256sum -c - \
 && tar xfz ${TARBALL} kustomize \
 && install kustomize /usr/local/bin/kustomize \
 && rm -f ${TARBALL} kustomize

# Install ksops, run by kustomize as a KRM exec plugin (--enable-exec)
ARG KSOPS_VERSION=4.5.1
ARG KSOPS_SHA256_amd64=9641e03a301bf2fc4b98d0e837a0351e1ca443ecd7a68b25e6af2149fbb2ef30
ARG KSOPS_SHA256_arm64=c7bb562cc2d580a1decc6c77a35e4d35575fb01ca003425726004ecd13dc1cb5
RUN cd /tmp/ \
 && SHA256_VAR=KSOPS_SHA256_${TARGETARCH} \
 && if [[ ${TARGETARCH} == 'amd64' ]]; then ARCH='x86_64'; else ARCH="${TARGETARCH}"; fi \
 && TARBALL=ksops_${KSOPS_VERSION}_Linux_${ARCH}.tar.gz \
 && curl -fsSLO https://github.com/viaduct-ai/kustomize-sops/releases/download/v${KSOPS_VERSION}/${TARBALL} \
 && echo "${!SHA256_VAR}  ${TARBALL}" | sha256sum -c - \
 && tar xfz ${TARBALL} ksops \
 && install ksops /usr/local/bin/ksops \
 && rm -f ${TARBALL} ksops

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

# Ansible configuration for running inside the deployment container
ENV ANSIBLE_CONFIG=/opt/deployment/pebbles-deploy/ansible_dc.cfg

# VIM is installed, so designate that as the default
ENV EDITOR=vim

# user content from this point on
WORKDIR /opt/deployment

# copy scripts and configs, change the owner to deployer
COPY bin bin
COPY bashrc .bashrc
COPY gitconfig .gitconfig
COPY vimrc .vimrc
COPY .config .config
RUN chown -R 29295:29295 bin .bashrc .gitconfig .vimrc .config

USER 29295

ENV HOME=/opt/deployment

# Add GitLab Helm repo for gitlab-runner
RUN helm repo add gitlab https://charts.gitlab.io

# Install Helm-Secrets plugin. Helm discovers plugins by directory, and installing one from a
# local path symlinks rather than copies it, so unpack the release straight into the plugin dir.
ARG HELM_SECRETS_VERSION=v4.7.7
ARG HELM_SECRETS_SHA256=3155c13d7d7d894f4c92c295ca50b21a6ab3d4492383c7c299ac0865783d694a
RUN cd /tmp/ \
 && TARBALL=helm-secrets.tar.gz \
 && curl -fsSLO https://github.com/jkroepke/helm-secrets/releases/download/${HELM_SECRETS_VERSION}/${TARBALL} \
 && echo "${HELM_SECRETS_SHA256}  ${TARBALL}" | sha256sum -c - \
 && mkdir -p ${HOME}/.local/share/helm/plugins \
 && tar xfz ${TARBALL} -C ${HOME}/.local/share/helm/plugins \
 && rm -f ${TARBALL}

# Copy the current build context so we can optionally consume a prebuilt
# pebbles-deploy source tarball if it has been staged there by build.bash.
COPY --chown=29295:29295 . /tmp/pebbles-deployer-build-context

# Use local pebbles-deploy snapshot if provided, otherwise fall back to cloning.
RUN if [[ -f /tmp/pebbles-deployer-build-context/pebbles-deploy-src.tar.gz ]]; then \
      mkdir -p /opt/deployment/pebbles-deploy && \
      tar -xzf /tmp/pebbles-deployer-build-context/pebbles-deploy-src.tar.gz \
          -C /opt/deployment/pebbles-deploy && \
      if [[ -f /tmp/pebbles-deployer-build-context/.version_info ]]; then \
          cp /tmp/pebbles-deployer-build-context/.version_info \
             /opt/deployment/pebbles-deploy/.version_info; \
      fi; \
    else \
      git clone "$PEBBLES_DEPLOY_SRC" && \
      cd pebbles-deploy && \
      git checkout "$PEBBLES_DEPLOY_REF"; \
    fi && \
    rm -rf /tmp/pebbles-deployer-build-context

CMD /bin/bash
