FROM quay.io/fedora/fedora:42

LABEL maintainer="CSC Noppe Team"

# Install packages
RUN dnf install -y \
    python-devel gcc pip butane\
 && dnf clean all

# Create a directory for application sources
RUN mkdir /opt/app

# Copy and install python requirements
COPY requirements.txt /opt/app/
RUN pip install --no-cache-dir --no-warn-script-location -r /opt/app/requirements.txt

# Copy sources over
COPY *.py /opt/app/
COPY *.j2 /opt/app/

WORKDIR /opt/app

RUN date -Is > BUILD

CMD /usr/bin/python3 main.py
