# Tailscale

Runs the official Tailscale Docker image as a standalone tailnet node. The
container uses kernel networking, persists its node state, and reconnects
automatically after restarts.

## Before deploying

1. Create an auth key in the [Tailscale admin console](https://login.tailscale.com/admin/settings/keys).
2. Set `TS_AUTHKEY` in the Arcane project environment. Do not commit the real
   key to a Compose file or `.env` file in source control.
3. Confirm that the Docker host exposes `/dev/net/tun`.

The default hostname is `tailscale`; set `TS_HOSTNAME` to the node name you
want displayed in the Tailscale admin console.

## Networking

This template creates a Tailscale node. It does not automatically attach
other application containers to the Tailscale network namespace. To make a
separate service reachable through this node, configure that service to share
the Tailscale container's network namespace, or use a purpose-built Compose
stack.

`NET_ADMIN`, `NET_RAW`, and `/dev/net/tun` are required for the kernel
networking mode used here.

## Source

Based on Tailscale's [standalone Docker container guide](https://tailscale.com/docs/features/containers/docker/how-to/connect-docker-standalone).
