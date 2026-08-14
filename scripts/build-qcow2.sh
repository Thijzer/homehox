#!/usr/bin/env bash
set -Eeuo pipefail

# Generate the VM disk. bootc-image-builder runs as root, so restore
# ownership afterward to keep output manageable by the normal user.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "$PROJECT_DIR"

if ! podman image exists localhost/fedora-bootc:latest; then
  echo "Building localhost/fedora-bootc:latest..."
  podman build --tag localhost/fedora-bootc:latest .
fi

sudo podman run \
  --rm \
  -it \
  --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v "$PROJECT_DIR/output:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v "$PROJECT_DIR/config.toml:/config.toml:ro" \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --rootfs ext4 \
  --use-librepo=True \
  --config /config.toml \
  localhost/fedora-bootc

sudo chown -R "$(id -u):$(id -g)" "$PROJECT_DIR/output"
