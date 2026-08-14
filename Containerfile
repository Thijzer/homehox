FROM quay.io/fedora/fedora-bootc:latest

RUN dnf -y install 'dnf5-command(config-manager)' && \
    dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo && \
    dnf -y install \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin && \
    dnf clean all && \
    rm -rf /var/cache/dnf

RUN systemctl enable docker.service

LABEL org.opencontainers.image.title="homebox" \
      org.opencontainers.image.description="Homebox immutable Fedora appliance with Docker CE and Arcane"
