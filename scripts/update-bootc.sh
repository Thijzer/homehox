#!/usr/bin/env bash
set -Eeuo pipefail

# Run on an installed Homebox host. The image must be the same bootc image
# format that is published by CI. bootc stages updates transactionally; the
# running deployment changes only after reboot.
IMAGE="${BOOTC_IMAGE:-ghcr.io/thijzer/homebox:stable}"
REBOOT=false

usage() {
    cat <<EOF
Usage: $0 [--image IMAGE] [--reboot]

  --image IMAGE  OCI image to switch to (default: ${IMAGE})
  --reboot       Reboot after a successful staged update

Examples:
  sudo $0 --image ghcr.io/thijzer/homebox:v1.2.3 --reboot
  sudo $0 --image ghcr.io/thijzer/homebox:stable
EOF
}

while (($#)); do
    case "$1" in
        --image) (($# >= 2)) || { echo "--image requires a value" >&2; exit 2; }; IMAGE="$2"; shift 2 ;;
        --reboot) REBOOT=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v bootc >/dev/null || { echo "bootc is not installed" >&2; exit 1; }

if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=()
else
    SUDO=(sudo)
fi

printf 'Staging bootc deployment from %s...\n' "$IMAGE"
"${SUDO[@]}" bootc switch "$IMAGE"
printf '\nStaged deployment:\n'
"${SUDO[@]}" bootc status

if [[ "$REBOOT" == true ]]; then
    echo "Rebooting into the staged deployment..."
    "${SUDO[@]}" systemctl reboot
else
    echo "Update is staged. Reboot to activate it, or rerun with --reboot."
fi
