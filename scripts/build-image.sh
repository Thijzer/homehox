#!/usr/bin/env bash
set -Eeuo pipefail

# Build the bootc OCI image locally. Publishing is intentionally separate;
# CI publishes immutable tags to GHCR.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
IMAGE="${IMAGE:-localhost/homebox:latest}"

usage() {
    cat <<EOF
Usage: $0 [--tag TAG] [--push]

Build the Homebox bootc image with podman.
  --tag TAG   Image tag or full image reference (default: ${IMAGE})
  --push      Push the resulting image (requires podman login)

Examples:
  $0 --tag localhost/homebox:dev
  $0 --tag ghcr.io/thijzer/homebox:v1.0.0 --push
EOF
}

PUSH=false
while (($#)); do
    case "$1" in
        --tag) (($# >= 2)) || { echo "--tag requires a value" >&2; exit 2; }; IMAGE="$2"; shift 2 ;;
        --push) PUSH=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

cd "$PROJECT_DIR"
podman build --tag "$IMAGE" .

if [[ "$PUSH" == true ]]; then
    podman push "$IMAGE"
fi

echo "Built: $IMAGE"
