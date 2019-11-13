FROM centos:8

LABEL maintainer="CSC Notebooks Team"

# Install base packages
RUN dnf install -y \
        openssh-clients \
        python36-devel python3-pip \
        gcc openssl-devel openssl \
        jq \
        tmux less git man bash-completion \
    && \
    dnf clean all

# Install python requirements
COPY requirements.txt /root/requirements.txt
RUN pip3 install --no-cache-dir -U setuptools
RUN pip3 install --no-cache-dir -r /root/requirements.txt

# Install helm
RUN cd /tmp/ && curl -LOs https://git.io/get_helm.sh && chmod 700 get_helm.sh && ./get_helm.sh -v v3.0.0-beta.3
RUN /usr/local/bin/helm completion bash > /etc/bash_completion.d/helm
# Install oc and kubectl
RUN cd /tmp/ \
 && curl -LOs https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz \
 && tar xf openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz \
 && cp openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/oc /usr/local/bin/. \
 && cp openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/kubectl /usr/local/bin/.
RUN /usr/local/bin/oc completion bash > /etc/bash_completion.d/oc

# Choose an arbitrary GID so that vault password can be made group readable when mounted as a volume
# in a reasonably safe way
RUN groupadd -g 29295 deployer
RUN useradd -u 29295 -g deployer -d /opt/deployment deployer

# set pebbles-deploy ansible_dc.cfg as the default
# when all deployments use pebbles-deploy, this can be unified to ansible.cfg
ENV ANSIBLE_CONFIG=/opt/deployment/pebbles-deploy/ansible_dc.cfg

USER 29295

WORKDIR /opt/deployment

COPY init_env.bash init_env.bash
COPY bashrc .bashrc

CMD /bin/bash
