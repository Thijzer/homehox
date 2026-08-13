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

I'd settle on:

```text
fedora-bootc/
├── Containerfile
├── kargs.toml
├── output/
└── README.md
```

`output/` is generated and shouldn't be committed to Git.

Add:

```gitignore
output/
*.qcow2
*.oci
```

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

Once Docker is working:

```bash
mkdir -p /opt/arcane
cd /opt/arcane
```

Create `compose.yaml`:

```yaml
services:
  arcane:
    image: ghcr.io/getarcaneapp/manager:latest
    container_name: arcane
    restart: unless-stopped

    ports:
      - "3552:3552"

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - arcane-data:/app/data

    environment:
      APP_URL: http://YOUR_VM_IP:3552
      PUID: "1000"
      PGID: "1000"
      ENCRYPTION_KEY: "REPLACE_ME"
      JWT_SECRET: "REPLACE_ME"

volumes:
  arcane-data:
```

Generate the secrets:

```bash
openssl rand -hex 32
```

Run that twice, and put the results into `ENCRYPTION_KEY` and `JWT_SECRET`.

Then:

```bash
docker compose up -d
```

Arcane's current documentation recommends Docker Compose and this general architecture: Arcane container + Docker socket + persistent `/app/data` volume. It listens on port 3552 by default. ([getarcane.app][4])

Open:

```text
http://VM-IP:3552
```

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
