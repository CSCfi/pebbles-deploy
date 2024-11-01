FROM docker.io/library/almalinux:8

LABEL maintainer="CSC Noppe Team"
RUN dnf makecache

# Install base packages
RUN dnf install -y \
    rsync \
    which \
    diffutils \
    findutils \
    xz \
    epel-release \
 && dnf clean all

# Add s3cmd for dealing with Allas object storage with S3 credentials from
RUN dnf install -y \
        s3cmd \
 && dnf clean all

# Add PostgreSQL 15, the client version needs to be equal or higher than server
RUN ARCH=$(uname -m) \
 && dnf install -y \
    https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-${ARCH}/pgdg-redhat-repo-latest.noarch.rpm \
 && dnf -qy module disable postgresql \
 && dnf install -y postgresql15 \
 && dnf clean all

# Add postgresql bin to path for pg_isready
ENV PATH=$PATH:/usr/pgsql-15/bin/

# add a user
RUN groupadd -g 29295 deployer
RUN useradd -u 29295 -g deployer -d /opt/deployment deployer

# make home directory writable and accessible under openshift
RUN chgrp -R root /opt/deployment \
 && find /opt/deployment -type d -exec chmod g+rwx,o+rx {} \; \
 && find /opt/deployment -type f -exec chmod g+rw {} \;

# user content from this point on
USER 29295

WORKDIR /opt/deployment
ENV HOME=/opt/deployment

CMD /bin/bash
