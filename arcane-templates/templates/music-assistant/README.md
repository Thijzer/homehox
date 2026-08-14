# Music Assistant

Music Assistant is a music server designed to discover, manage, and stream
music to networked players. This template uses the official Music Assistant
container image and the installation's required host networking mode.

## Before deploying

1. Set `MUSIC_ASSISTANT_DATA_PATH` to a persistent writable directory.
2. Set `MUSIC_ASSISTANT_MEDIA_PATH` to a host directory containing local music,
   or leave the default empty directory if using only streaming providers.
3. Ensure the Docker host and all Music Assistant player devices are on the
   same flat Layer 2 network.
4. Deploy the project and open `http://<host>:8095`.

The data directory is mounted at `/data`. The optional local music directory is
mounted read-only at `/media`.

## Networking

`network_mode: host` is intentional and required for supported Docker
installations. Music Assistant uses mDNS, uPnP, and other local-network
protocols to discover and communicate with AirPlay, Chromecast, DLNA, Sonos,
and other players. Host networking also allows players to reach the default
stream port, TCP `8097`, and other dynamically used ports.

Because host networking is used, this Compose file does not define a `ports:`
section. The web UI is normally available at port `8095` on the host.

## Permissions and remote shares

This template deliberately does not grant `SYS_ADMIN`, `DAC_READ_SEARCH`, or
`apparmor:unconfined`. Those broad privileges are only needed when Music
Assistant mounts SMB/NFS shares itself. Prefer mounting network shares on the
host and exposing them through `MUSIC_ASSISTANT_MEDIA_PATH` read-only.

## Requirements

Music Assistant requires a 64-bit operating system and at least 2 GB of RAM;
4 GB or more is recommended when running other services. The first library
synchronization may take some time.

## Updates

`MUSIC_ASSISTANT_IMAGE_TAG` defaults to `latest` to match the upstream example.
Use a specific release tag when reproducible updates are more important than
automatic tracking.

## Source

Based on the [Music Assistant Docker installation guide](https://www.music-assistant.io/installation/).
