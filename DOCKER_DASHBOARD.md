# EasyTier Web Console Docker Image

Image: `docker.io/invokerkael/easytier-dashboard:v2.7.0`

This image wraps the upstream multi-architecture EasyTier `v2.7.0` image and starts `easytier-web-embed` by default.

## Runtime defaults

- Web/API: TCP port `11211`
- Configuration server: UDP port `22020`
- Database: `/data/et.db`
- The web UI may require selecting the API server address when `--api-host` is not set.

Mount `/data` to persistent storage. Expose TCP `11211` only through a trusted path. Publish UDP `22020` only when remote EasyTier clients need to reach this configuration server.

## Upgrade note

`v2.7.0` is an upstream prerelease. It migrates the Web management database. Back up `/data` before upgrading and restore that backup if rolling back. Clients using the old token-only `--config-server` shorthand must switch to a full server URL. Legacy WireGuard portal configurations also require migration.

The image is published with a versioned tag only; it does not replace `latest`.
