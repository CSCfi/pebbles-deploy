FROM quay.io/fedora/fedora:34

LABEL maintainer="CSC Notebooks Team"

# Install packages
RUN dnf install -y \
    python pip butane\
 && dnf clean all

# Copy sources over
RUN mkdir /opt/app
COPY *.py /opt/app/
COPY requirements.txt /opt/app/

# Install python requirements
RUN pip install --no-cache-dir -r /opt/app/requirements.txt

WORKDIR /opt/app

CMD /usr/bin/python main.py
