#!/usr/bin/env bash
set -Eeuo pipefail

# Generate the VM disk. bootc-image-builder runs as root, so restore
# ownership afterward to keep output manageable by the normal user.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_DIR"
[[ -f config.toml ]] || { echo "Missing config.toml" >&2; exit 1; }

# SSH keys authenticate SSH, but sudo requires a user password. Keep the
# password as a hash in a temporary config file only.
read -r -s -p "User Password (used by sudo): " password
echo
read -r -s -p "Repeat password: " password_confirm
echo
[[ "$password" == "$password_confirm" ]] || { echo "Passwords do not match." >&2; exit 1; }
[[ -n "$password" ]] || { echo "Password may not be empty." >&2; exit 1; }

password_hash="$(printf '%s' "$password" | openssl passwd -6 -stdin)"
unset password password_confirm
CONFIG_FILE="$(mktemp)"
trap 'rm -f "$CONFIG_FILE"' EXIT

awk -v hash="$password_hash" '
    /^password[[:space:]]*=/ { next }
    /^name[[:space:]]*=/ && !inserted {
        print
        print "password = \"" hash "\""
        inserted = 1
        next
    }
    { print }
' config.toml > "$CONFIG_FILE"
unset password_hash

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
  -v "$CONFIG_FILE:/config.toml:ro" \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --rootfs ext4 \
  --use-librepo=True \
  --config /config.toml \
  localhost/fedora-bootc

sudo chown -R "$(id -u):$(id -g)" "$PROJECT_DIR/output"
