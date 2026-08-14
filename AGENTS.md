# AGENTS.md

## Project

This repository builds a Fedora bootc VM image with Docker CE and deploys it to Proxmox.

## Important files

- `Containerfile` — Fedora bootc image definition.
- `config.toml` — bootc user customization and SSH public key.
- `scripts/build-qcow2.sh` — builds `output/qcow2/disk.qcow2`.
- `scripts/deploy-proxmox.sh` — imports the image into Proxmox VM `103`.
- `output/` — generated build artifacts; never commit them.

## Development rules

- Keep scripts Bash-compatible and run `bash -n` after changes.
- Do not store plaintext passwords or private SSH keys in the repository.
- `config.toml` may contain a public SSH key only.
- Passwords for sudo are entered interactively by `build-qcow2.sh` and stored only as temporary hashes during the build.
- Preserve the existing default Proxmox settings unless explicitly requested:
  - Host: `192.168.1.s`
  - VM ID: `200`
  - Storage: `local-lvm`
  - Disk: `scsi0`, VirtIO SCSI, discard enabled, iothread enabled
- Do not use destructive Proxmox operations without an explicit `--replace` request.

## Validation

For script changes:

```bash
bash -n scripts/build-qcow2.sh
bash -n scripts/deploy-proxmox.sh
```

Do not run a full image build or replace a Proxmox disk unless requested.
