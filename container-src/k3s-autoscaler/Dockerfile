FROM docker.io/library/fedora:44@sha256:43b29f65a41eb9c35e1cd5323e3bdf3b655c2357a9f4f1ff2f9c2798e5045d80

LABEL maintainer="CSC Noppe Team"

# Install packages
RUN dnf install -y \
    pip butane \
 && dnf clean all

# Create a directory for application sources
RUN mkdir /opt/app

# Copy and install python requirements
COPY requirements.txt /opt/app/
RUN pip install --no-cache-dir --no-warn-script-location --require-hashes --only-binary=:all: -r /opt/app/requirements.txt

# Copy sources over
COPY *.py /opt/app/
COPY *.j2 /opt/app/

WORKDIR /opt/app

RUN date -Is > BUILD

CMD /usr/bin/python3 main.py
