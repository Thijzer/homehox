# Homebox image release process

This project has two deliverables built from the same `Containerfile`:

- an OCI bootc image in GHCR, used for upgrades and new installations;
- a QCOW2 generated from that image, used to create or replace a Proxmox VM.

The OCI image is the source of truth. A QCOW2 is a deployment artifact, not a
separate release line.

## Channels and tags

The package is `ghcr.io/thijzer/homehox` (the repository name is historical).
CI publishes:

| Tag | Meaning | Recommended use |
|---|---|---|
| `sha-<commit>` | immutable build identifier | diagnostics and pinning |
| `v1.2.3` | immutable release | production change records |
| `stable` | moving pointer to the newest version tag | normal host updates |
| `latest` | moving pointer for builds on `master` | development/testing |

Hosts should use `stable`, or an exact `vX.Y.Z` tag during a controlled
rollout. Do not use `latest` for production.

## Making a release

1. Make and review the `Containerfile` (and any image inputs) change.
2. Run local checks:

   ```bash
   bash -n scripts/build-image.sh scripts/build-qcow2.sh scripts/deploy-proxmox.sh
   podman build --tag localhost/homebox:check .
   ```

3. Merge to `master`. The workflow builds and publishes a commit tag and
   `latest`; pull requests build without publishing.
4. Create and push an annotated semantic-version tag:

   ```bash
   git tag -a v1.2.3 -m 'Release v1.2.3'
   git push origin v1.2.3
   ```

   The tag workflow publishes `v1.2.3` and moves `stable` to that exact
   build. The GitHub Actions run and the GHCR digest are the release record.
5. Test the exact tag in a disposable VM before updating the production host.
6. Update hosts with `scripts/update-bootc.sh`; reboot only when the change
   window permits it. See [GHCR and bootc updates](GHCR.md).
7. Keep the previous version tag available for rollback. Rollback is a bootc
   deployment action, not a rebuild of an old QCOW2.

A tag must not be moved after publication. If a release is wrong, publish a
new patch version.

## QCOW2 releases

A new VM or a deliberate Proxmox replacement uses the OCI image selected by
the local build. Build it locally with:

```bash
podman pull ghcr.io/thijzer/homehox:v1.2.3
IMAGE=ghcr.io/thijzer/homehox:v1.2.3 ./scripts/build-qcow2.sh
```

`build-qcow2.sh` accepts the `IMAGE` environment variable and passes that
reference to bootc-image-builder. The script also transfers a rootless image
into rootful Podman storage when needed, because the image builder runs as
root. This keeps the QCOW2 tied to the exact release that was tested; no
retagging is required.

Do not run `deploy-proxmox.sh --replace` as part of an unattended release.
It deliberately requires an explicit flag and confirmation. Prefer a fresh
VM or a bootc update; use replacement only after backup and a maintenance
window.

## Rollback

Before a reboot, inspect the staged deployment with `sudo bootc status`.
After a bad boot, select the previous deployment from the boot loader or use
the documented bootc rollback procedure. Pinning a known-good tag with
`sudo scripts/update-bootc.sh --image ghcr.io/thijzer/homehox:v1.2.2` is useful
for recovery, but retain application backups and verify the resulting status.
