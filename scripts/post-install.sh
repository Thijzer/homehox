#!/usr/bin/env bash
set -Eeuo pipefail

# Entry point for mutable, first-boot application installation. Each service
# remains a separate installer so adding Tailscale does not alter Arcane state.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [arcane]"
    echo
    echo "  arcane  Prepare the host and install/update Arcane (default)"
    echo
    echo "Run this on the deployed VM, for example:"
    echo "  ssh thijzer@192.168.1.154 'bash -s -- arcane' < scripts/post-install.sh"
}

case "${1:-arcane}" in
    arcane)
        "$SCRIPT_DIR/post-install/install-arcane.sh"
        ;;
    -h|--help)
        usage
        ;;
    *)
        echo "Unknown service: $1" >&2
        usage >&2
        exit 2
        ;;
esac
