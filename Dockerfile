FROM debian:bookworm-slim

WORKDIR /opt/flair

# Create necessary directories 
RUN mkdir -p /opt/flair && mkdir -p /var/log/flair

# Copy over required files
COPY . /opt/flair

RUN groupadd -g 7777 flair && \
    useradd -c "Flair User" -g "flair" -u 7777 -d /opt/flair -M -s /bin/bash flair && \
    chown -R flair:flair /opt/flair && \
    chown -R flair:flair /var/log/flair
    
USER flair
