# Technitium DNS Server

Technitium DNS Server is an authoritative and recursive DNS server with a web
console and support for features such as blocking, DNS-over-TLS, DNS-over-
HTTPS, and DNS-over-QUIC.

## Before deploying

1. Ensure TCP and UDP port `53` are available on the Homebox host.
2. Set `TECHNITIUM_ADMIN_PASSWORD` in the Arcane project environment to a
   strong password. Do not commit the real password.
3. Set `TECHNITIUM_DOMAIN` to the fully qualified domain name the server should
   use to identify itself.
4. Keep `TECHNITIUM_CONFIG_PATH` and `TECHNITIUM_LOG_PATH` on persistent
   storage.
5. Deploy the project and open `http://<host>:${TECHNITIUM_WEB_PORT}`.

The template publishes the following services by default:

| Host port | Protocol | Service |
| --- | --- | --- |
| `53` | TCP/UDP | DNS-over-TCP and DNS-over-UDP |
| `443` | TCP | DNS-over-HTTPS (HTTP/1.1 and HTTP/2) |
| `443` | UDP | DNS-over-HTTPS3 (HTTP/3) |
| `853` | TCP | DNS-over-TLS |
| `853` | UDP | DNS-over-QUIC |
| `5380` | TCP | Web UI and API over HTTP |
| `53443` | TCP | Web UI and API over HTTPS |

The host ports are configurable through the `TECHNITIUM_*_PORT` variables in
`.env`. The DNS service listens on both TCP and UDP port `53` by default.

## Storage

The template persists the following directories:

```text
/etc/dns                  DNS configuration, zones, and server state
/var/log/technitium/dns   DNS server logs
```

The default host paths are relative to the Arcane project directory. For the
Homebox host, persistent paths under `/var/lib/homebox/services/technitium-dns`
are also suitable.

## Networking and DHCP

The default bridge-network configuration publishes DNS, encrypted DNS
protocols, and both web-console ports. Ensure these host ports are available;
`443`, `853`, and `53` are commonly used by other services and reverse
proxies.

The upstream example recommends host networking for DHCP deployments; if DHCP
is required, change the Compose file to use `network_mode: host` and remove the
`ports` section and the `net.ipv4.ip_local_port_range` sysctl.

Do not expose a recursive DNS server or its web console directly to the public
internet. Restrict access with the Homebox firewall or the surrounding network
configuration.

## Updates

`TECHNITIUM_IMAGE_TAG` defaults to `latest` to follow the upstream Compose
example. Use a specific release tag when reproducible updates are preferred.
Review release notes before recreating the container.

## Source

Based on the [official Technitium DNS Server Docker Compose file](https://github.com/TechnitiumSoftware/DnsServer/blob/master/docker-compose.yml).
