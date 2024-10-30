# Start with debian:bookworm image with scot4 perl installed
FROM ghcr.io/sandialabs/scot4-perl-builder@sha256:6a92390d96baf3c1ad73fcdf9af5047a36e880c5ce026c91cff98d0064e2e67f

WORKDIR /opt/flair

# Create necessary directories 
RUN mkdir -p /opt/flair && mkdir -p /var/log/flair

# Copy over required files
COPY . /opt/flair

RUN groupadd -g 7777 flair && \
    useradd -c "Flair User" -g "flair" -u 7777 -d /opt/flair -M -s /bin/bash flair && \
    chown -R flair:flair /opt/flair && \
    chown -R flair:flair /var/log/flair && \
    chmod +x /opt/flair/setup.pl

USER flair
