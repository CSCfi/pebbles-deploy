FROM quay.io/fedora/fedora:36

LABEL maintainer="CSC Notebooks Team"

# Install packages
RUN dnf install -y \
    python-devel gcc pip butane\
 && dnf clean all

# Create a directory for application sources
RUN mkdir /opt/app

# Copy and install python requirements
COPY requirements.txt /opt/app/
RUN pip install --no-cache-dir -r /opt/app/requirements.txt

# Copy sources over
COPY *.py /opt/app/
COPY *.j2 /opt/app/

WORKDIR /opt/app

CMD /usr/bin/python3 main.py
