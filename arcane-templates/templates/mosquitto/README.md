# Eclipse Mosquitto

Eclipse Mosquitto is a lightweight MQTT broker for connected devices, IoT,
and home automation workloads.

## Before deploying

The official image expects a broker configuration under
`/mosquitto/config`. This template intentionally requires a host-mounted
configuration directory so authentication and listener settings remain
explicit.

1. Copy `mosquitto.conf.example` to the configured host directory as
   `mosquitto.conf`.
2. Generate a password file in that same directory:

   ```bash
   mosquitto_passwd -c ./mosquitto-config/passwd mqtt-user
   ```

   Use the `mosquitto_passwd` utility from a Mosquitto installation or a
   temporary Mosquitto container.
3. Set `MOSQUITTO_CONFIG_PATH` to the directory containing `mosquitto.conf`
   and `passwd`.
4. Set `MOSQUITTO_DATA_PATH` and `MOSQUITTO_LOG_PATH` to persistent writable
   directories.
5. Deploy the project and connect clients to `<host>:${MOSQUITTO_MQTT_PORT}`.

The example configuration enables persistence and disables anonymous access.
Do not expose an unauthenticated MQTT listener to an untrusted network.

## Storage

The image uses these paths:

```text
/mosquitto/config  broker configuration and password file
/mosquitto/data    persistent retained messages and subscriptions
/mosquitto/log     broker logs
```

Keep the password file private and back up the data directory if retained
messages and subscriptions are important.

## Networking

This template exposes MQTT over TCP on port `1883` by default. Change
`MOSQUITTO_MQTT_PORT` if the host port is already in use.

TLS, WebSockets, bridges, and additional listeners require corresponding
entries in `mosquitto.conf` and additional port mappings in the Compose file.
Do not add broad container privileges for these features.

## Updates

`MOSQUITTO_IMAGE_TAG` is pinned to an explicit Alpine release tag. Review
upstream release notes before changing it and recreate the container after an
image update.

## Source

Based on the [official Eclipse Mosquitto image documentation](https://hub.docker.com/_/eclipse-mosquitto).
