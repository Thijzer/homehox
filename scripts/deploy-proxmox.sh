#!/usr/bin/env bash
set -Eeuo pipefail

# Build and import the Fedora bootc QCOW2 image into Proxmox.
# By default this refuses to overwrite an existing VM disk.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.10}"
VMID="${VMID:-103}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
IMAGE="${PROJECT_DIR}/output/qcow2/disk.qcow2"
REMOTE_IMAGE="/var/lib/vz/dump/disk-${VMID}.qcow2"
REPLACE=false

usage() {
    echo "Usage: $0 [--replace]"
    echo
    echo "  --replace  Stop VM ${VMID} and replace its existing scsi0 disk"
    echo
    echo "Environment overrides: PROXMOX_HOST, VMID, STORAGE, BRIDGE"
}

for arg in "$@"; do
    case "$arg" in
        --replace) REPLACE=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ "$REPLACE" == true ]]; then
    read -r -p "DESTROY the existing scsi0 disk of VM ${VMID}? Type REPLACE: " confirm
    [[ "$confirm" == REPLACE ]] || { echo "Cancelled."; exit 1; }
fi

cd "$PROJECT_DIR"

[[ -f config.toml ]] || { echo "Missing config.toml" >&2; exit 1; }
[[ -f "$IMAGE" ]] || { echo "QCOW2 was not generated: $IMAGE" >&2; exit 1; }

echo "Copying image to ${PROXMOX_HOST}..."
scp "$IMAGE" "root@${PROXMOX_HOST}:${REMOTE_IMAGE}"

ssh "root@${PROXMOX_HOST}" bash -s -- "$VMID" "$STORAGE" "$REMOTE_IMAGE" "$REPLACE" <<'REMOTE_SCRIPT'
set -Eeuo pipefail
VMID="$1"
STORAGE="$2"
REMOTE_IMAGE="$3"
REPLACE="$4"

qm status "$VMID" >/dev/null 2>&1 || {
    echo "VM ${VMID} does not exist. Create it in Proxmox first." >&2
    exit 1
}

if [[ "$REPLACE" == true ]]; then
    qm stop "$VMID" --skiplock 2>/dev/null || true
    OLD_DISK="$(qm config "$VMID" | awk -F': ' '/^scsi0:/{print $2; exit}' | cut -d, -f1)"
    qm set "$VMID" --delete scsi0
    if [[ -n "$OLD_DISK" ]]; then
        pvesm free "$OLD_DISK"
    fi
fi

qm importdisk "$VMID" "$REMOTE_IMAGE" "$STORAGE" --format raw

UNUSED="$(qm config "$VMID" | awk -F': ' '/^unused[0-9]+:/{print $2; exit}')"
[[ -n "$UNUSED" ]] || { echo "Could not find imported unused disk." >&2; exit 1; }

if qm config "$VMID" | grep -q '^scsi0:'; then
    echo "Existing scsi0 retained. Imported disk is available as: $UNUSED"
    echo "Attach it manually after stopping the VM, or rerun with --replace."
else
    qm set "$VMID" --scsihw virtio-scsi-single --scsi0 "${UNUSED},discard=on,iothread=1"
    qm set "$VMID" --boot order=scsi0
fi

rm -f "$REMOTE_IMAGE"
echo "Done. VM ${VMID} can be started with: qm start ${VMID}"
REMOTE_SCRIPT
