#!/usr/bin/env bash
set -Eeuo pipefail

# Shared, idempotent preparation for services installed after first boot.
# Keep service-specific setup out of this script so future installers (for
# example Tailscale) can reuse the host preparation without Arcane coupling.

# /opt is part of the immutable deployment on bootc; keep all mutable
# application state under /var.
ARCANE_ROOT="${ARCANE_ROOT:-/var/lib/arcane}"
PROJECTS_DIR="${PROJECTS_DIR:-/var/lib/arcane/projects}"
BUILDS_DIR="${BUILDS_DIR:-/var/lib/arcane/builds}"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Required command not found: $1" >&2
        exit 1
    }
}

require_command docker
require_command systemctl

# Obtain the sudo credential once. All privileged preparation stays here so
# service-specific installers do not need to know about host permissions.
if [[ "$(id -u)" -ne 0 ]]; then
    sudo -v
fi

run_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

configure_dns_stub_listener() {
    # systemd-resolved's 127.0.0.53:53 stub listener conflicts with Docker
    # services such as Technitium DNS that need to bind 0.0.0.0:53. Disable
    # only the stub listener; resolved can continue managing upstream DNS.
    if ! systemctl is-active --quiet systemd-resolved.service 2>/dev/null; then
        return
    fi

    run_root install -d -m 0755 /etc/systemd/resolved.conf.d
    run_root tee /etc/systemd/resolved.conf.d/90-homebox-dns.conf >/dev/null <<'EOF'
[Resolve]
DNSStubListener=no
EOF

    run_root systemctl restart systemd-resolved.service

    # Point applications at resolved's non-stub resolver configuration. This
    # keeps host name resolution working after the stub listener is disabled.
    if [[ -e /run/systemd/resolve/resolv.conf ]]; then
        run_root ln -sfn /run/systemd/resolve/resolv.conf /etc/resolv.conf
    fi
}

configure_dns_stub_listener

if ! systemctl is-enabled --quiet docker.service 2>/dev/null; then
    if [[ "$(id -u)" -eq 0 ]]; then
        systemctl enable docker.service
    else
        sudo systemctl enable docker.service
    fi
fi

if ! systemctl is-active --quiet docker.service; then
    if [[ "$(id -u)" -eq 0 ]]; then
        systemctl start docker.service
    else
        sudo systemctl start docker.service
    fi
fi

docker info >/dev/null 2>&1 || {
    echo "Docker is not available to the current user." >&2
    echo "Ensure $(id -un) is in the docker group, then start a new login session." >&2
    exit 1
}

docker compose version >/dev/null 2>&1 || {
    echo "Docker Compose v2 is required (the docker compose plugin was not found)." >&2
    exit 1
}

# These are mutable application paths; do not put them in the immutable OS
# image. sudo is only needed when the script is run as an unprivileged user.
if [[ "$(id -u)" -eq 0 ]]; then
    install -d -m 0755 "$ARCANE_ROOT" "$PROJECTS_DIR" "$BUILDS_DIR"
else
    sudo install -d -m 0755 "$ARCANE_ROOT" "$PROJECTS_DIR" "$BUILDS_DIR"
    sudo chown "$(id -u):$(id -g)" "$ARCANE_ROOT" "$PROJECTS_DIR" "$BUILDS_DIR"
fi

echo "Host preparation complete."
echo "  Service root: $ARCANE_ROOT"
echo "  Projects:     $PROJECTS_DIR"
echo "  Builds:       $BUILDS_DIR"
