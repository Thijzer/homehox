# FreshRSS

FreshRSS is a free, self-hosted RSS and Atom feed aggregator using the
LinuxServer.io container image.

## First deployment

1. Review the values in `.env.example`.
2. Set `PUID`, `PGID`, and `TZ` for the user and timezone that should own the
   persistent configuration directory.
3. Deploy the project in Arcane.
4. Open `http://<host>:${FRESHRSS_PORT}` and complete the FreshRSS setup
   wizard.

The template stores persistent application data in the directory configured by
`FRESHRSS_CONFIG_PATH` and exposes the web UI on `FRESHRSS_PORT`.

## Database

FreshRSS can use its supported standalone database configuration or an
external MySQL/MariaDB or PostgreSQL database. If using an external database,
create a non-root database user and complete the database settings in the
FreshRSS setup wizard.

## Updates and security

`FRESHRSS_IMAGE_TAG` defaults to `latest` to match the LinuxServer.io example.
Use an explicit version tag when reproducible updates are more important than
automatic image tracking. Review image updates before recreating the
container.

The configuration directory may contain application data and credentials;
keep it out of source control and back it up separately.

## Source

Based on the [LinuxServer.io FreshRSS image documentation](https://docs.linuxserver.io/images/docker-freshrss).
