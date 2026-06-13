FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    ipmitool \
    iputils-ping \
    traceroute \
    bsdmainutils \
    curl \
    dnsutils \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --break-system-packages \
    oauthlib \
    pynetbox \
    redfish \
    requests \
    requests-oauthlib

WORKDIR /git

CMD ["/bin/bash"]
