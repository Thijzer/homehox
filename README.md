## Fedora bootc + Docker + Arcane

The overall design is:

```text
                    Containerfile
                         │
                         ▼
                Fedora bootc image
                         │
                ┌────────┴────────┐
                ▼                 ▼
             QCOW2             OCI image
                │                 │
                ▼                 ▼
          VM / Proxmox       Physical host
                                  │
                                  ▼
                              Docker
                                  │
                                  ▼
                               Arcane
                                  │
                                  ▼
                           Docker containers
```

bootc treats the OS itself as an OCI/Docker image, including the kernel, and deploys it as a normal host OS rather than running the OS inside a container. ([bootc.dev][1])

---

# 1. Project layout

Post-install services are deliberately separated from the immutable OS image:

```text
scripts/
├── post-install.sh                    # service dispatcher
└── post-install/
    ├── prepare-host.sh                # shared Docker/filesystem checks
    └── install-arcane.sh              # Arcane-specific Compose deployment
```

After deploying a fresh VM, run the Arcane installer interactively on the VM:

```bash
scp -r scripts/post-install.sh scripts/post-install thijzer@192.168.1.154:/tmp/
ssh -t thijzer@192.168.1.154 'bash /tmp/post-install.sh arcane'
```

Because bootc keeps `/opt` immutable, the installer keeps Arcane's Compose
file, generated secrets, and data under `/var/lib/arcane/`. Projects and builds
are stored under `/var/lib/arcane/projects` and `/var/lib/arcane/builds`.
Secrets are generated on the VM and are not stored in this repository. Future
services such as Tailscale should get their own installer under
`scripts/post-install/` and be added as a separate dispatcher action.


`output/` contains generated build artifacts and should not be committed.

---


# 4. Build the bootc image

From your project directory:

```bash
podman build \
    -t localhost/fedora-bootc:latest \
    .
```

Check:

```bash
podman images localhost/fedora-bootc
```

---

# 5. Generate the QCOW2

This is the command you've now got working:

```bash
sudo podman run \
    --rm \
    -it \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./output:/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type qcow2 \
    --rootfs ext4 \
    --use-librepo=True \
    localhost/fedora-bootc
```

The important bit for your Fedora image is:

```text
--rootfs ext4
```

I'd keep that in your documented build command since you've confirmed it works with your current image/builder combination.

You should end up with something under:

```text
output/
└── qcow2/
    └── ...
```

Check:

```bash
find output -type f -ls
```

---

# 6. Test it in a VM

For a generic QEMU/KVM test:

```bash
qemu-img info output/qcow2/disk.qcow2
```

Then create a VM with roughly:

```text
CPU       4 cores
RAM       8 GB
Disk      use generated QCOW2
Firmware  UEFI
Network   VirtIO
```

If you're using Proxmox, import the QCOW2 into a VM rather than installing Fedora from an ISO.

The important advantage here is that you're testing **the exact bootable image you're eventually going to deploy**.

---

# 7. First boot

Once the VM boots:

```bash
bootc status
```

Then:

```bash
cat /proc/cmdline
```

Check Docker:

```bash
systemctl status docker
```

and:

```bash
docker version
```

Finally:

```bash
docker run --rm hello-world
```

Docker's Fedora documentation uses the same `hello-world` test to verify a successful installation. ([Docker Documentation][2])

---

# 8. Check the immutable OS

This is where bootc differs from a conventional Fedora installation.

Run:

```bash
bootc status
```

You should see information about your current deployment.

Also:

```bash
mount | grep ' /usr '
```

The general bootc model is that the deployed OS filesystem is read-only by default, while mutable state lives outside the immutable image. ([bootc.dev][3])

Don't think of this as:

```text
Fedora
 └── apt/dnf everything manually
```

Think:

```text
Containerfile
      ↓
OS image
      ↓
deployment
      ↓
machine
```

---

# 9. Updating the OS

When you change the `Containerfile`, rebuild and publish a new image.

On the machine:

```bash
sudo bootc upgrade
```

Then:

```bash
sudo reboot
```

Check:

```bash
bootc status
```

If an update causes trouble, bootc supports rollback to the previous deployment. The transactional model is one of the main reasons to use bootc here. ([bootc.dev][1])

---

# 10. Don't put Arcane in the bootc image

I'd keep **Arcane out of `Containerfile`**.

The distinction should be:

### OS image

```text
Fedora
Docker
Docker Compose
kernel
kernel arguments
system configuration
```

### Docker state

```text
Arcane
your applications
databases
reverse proxies
monitoring
etc.
```

That means Arcane can be upgraded independently:

```text
bootc
  │
  └── manages OS

Docker
  │
  └── manages containers

Arcane
  │
  └── manages Docker workloads
```

That's a very clean separation.

---

# 11. Install Arcane

Arcane is installed after first boot rather than being baked into the
immutable OS image. The installer prepares Docker, creates the mutable
filesystem paths, generates secrets, and starts the official Arcane Compose
service:

```bash
scp -r scripts/post-install.sh scripts/post-install \\
  thijzer@192.168.1.154:/tmp/
ssh -t thijzer@192.168.1.154 \\
  'bash /tmp/post-install.sh arcane'
```

The installer stores all mutable Arcane state under `/var/lib/arcane`:

```text
/var/lib/arcane/
├── .env                  # generated secrets; mode 600
├── compose.yaml
├── projects/             # Arcane Compose projects
└── builds/               # project build files
```

The Arcane data volume is managed by Docker and mounted at `/app/data`. Arcane
is available at:

```text
http://192.168.1.154:3552
```

The installer is safe to rerun: existing secrets are preserved and the
container is updated through Compose. It also migrates project definitions
that still refer to `/data/compose`, a path that cannot be created on an
immutable bootc root filesystem, to `/var/lib/arcane/projects`.

To add another post-install service, such as Tailscale, create a separate
installer under `scripts/post-install/` and add a dispatcher action rather
than adding it to the Arcane setup.

---

# 12. What I would do next

At this point I'd **not add more complexity yet**.

Get this VM to the following state:

```text
┌──────────────────────────────┐
│        Fedora bootc          │
│                              │
│  immutable OS                │
│                              │
│  Docker ✓                    │
│  Compose ✓                   │
│                              │
│  ┌────────────────────────┐  │
│  │        Arcane          │  │
│  │       :3552            │  │
│  └───────────┬────────────┘  │
│              │               │
│       ┌──────┴───────┐       │
│       │              │       │
│    nginx          postgres   │
│    etc...         etc...     │
│                              │
└──────────────────────────────┘
```

Once that's working, I'd tackle these **in this order**:

1. **Your physical NIC kernel argument**
2. Persistent storage layout
3. Firewall/networking
4. Automatic bootc updates
5. Arcane backups
6. VM → physical deployment
7. Git-based image builds
8. Private/public OCI registry

The particularly nice end state is that your physical server won't be a hand-configured snowflake. You'll have:

```text
Git repository
     │
     ▼
Containerfile
     │
     ▼
Fedora bootc image
     │
     ├──────────────► VM
     │
     └──────────────► Physical server
```

And Arcane sits above that as the **application/container management layer**, which is exactly where I'd want it.

### Official docs worth bookmarking

* [bootc documentation](https://bootc.dev/bootc/?utm_source=chatgpt.com) — concepts, building images, installation and updates.
* [bootc image layout / compatibility](https://bootc.dev/bootc/bootc-images.html?utm_source=chatgpt.com) — useful when troubleshooting image-builder issues.
* [bootc installation documentation](https://bootc.dev/bootc/bootc-install.html?utm_source=chatgpt.com) — eventually useful when installing directly to the physical machine.
* [Docker Engine on Fedora](https://docs.docker.com/engine/install/fedora/?utm_source=chatgpt.com) — authoritative Docker package/repository instructions.
* [Arcane installation](https://getarcane.app/docs/setup/installation?utm_source=chatgpt.com) — Docker Compose setup.
* [Arcane documentation](https://getarcane.app/docs?utm_source=chatgpt.com) — the broader Arcane docs, including security, networking and remote environments.

[1]: https://bootc.dev/bootc/?utm_source=chatgpt.com "Introduction - bootc"
[2]: https://docs.docker.com/engine/install/fedora/?utm_source=chatgpt.com "Install Docker Engine on Fedora | Docker Docs"
[3]: https://bootc.dev/bootc/building/guidance.html?utm_source=chatgpt.com "Building images - bootc"
[4]: https://getarcane.app/docs/setup/installation?utm_source=chatgpt.com "Installation"
