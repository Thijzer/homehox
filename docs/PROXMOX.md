# Deploy the Homebox QCOW2 Image to Proxmox

This guide imports `output/qcow2/disk.qcow2` into a Proxmox VM.

The examples use:

- Proxmox server: `192.168.1.x`
- VM ID: `200`
- VM name: `homebox`
- Proxmox storage: `local-lvm`
- Network bridge: `vmbr0`

Change these values if your Proxmox configuration is different.

## 1. Verify the image locally

From the project directory:

```bash
cd /var/home/user/Projects/fedora-bootc
qemu-img info output/qcow2/disk.qcow2
```

The generated image should report a QCOW2 format and a virtual size of approximately 10 GiB.

## 2. Copy the image to Proxmox

Copy the image to a temporary location on the Proxmox server:

```bash
scp output/qcow2/disk.qcow2 root@192.168.1.x:/var/lib/vz/dump/
```

Verify the upload:

```bash
ssh root@192.168.1.x \
  'ls -lh /var/lib/vz/dump/disk.qcow2'
```

## 3. Create the VM

SSH into Proxmox:

```bash
ssh root@192.168.1.x
```

Check the available storage and existing VM IDs:

```bash
pvesm status
qm list
```

Create the VM:

```bash
qm create 200 \
  --name homebox \
  --memory 8192 \
  --cores 4 \
  --cpu host \
  --machine q35 \
  --ostype l26 \
  --bios seabios \
  --net0 virtio,bridge=vmbr0 \
  --agent enabled=1 \
  --onboot 1
```

If your network bridge is not `vmbr0`, check it with:

```bash
cat /etc/network/interfaces
```

## 4. Import and attach the disk

Import the QCOW2 into `local-lvm`:

```bash
qm importdisk 200 \
  /var/lib/vz/dump/disk.qcow2 \
  local-lvm \
  --format raw
```

Attach the imported disk as a SCSI disk:

```bash
qm set 200 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:vm-200-disk-0,discard=on,iothread=1
```

Set it as the boot disk:

```bash
qm set 200 --boot order=scsi0
```

If the imported volume has a different name, inspect the VM configuration and use the volume shown there:

```bash
qm config 200
```

## 5. Start and access the VM

Start the VM:

```bash
qm start 200
```

Open its console from the Proxmox web interface:

```text
https://192.168.1.x:8006
```

Select:

```text
VM 200 → Console
```

Log in as the configured user:

```text
user
```

Find the VM's IP address:

```bash
ip address
```

Then connect over SSH from your workstation:

```bash
ssh user@VM_IP_ADDRESS
```

The image includes the SSH public key configured in `config.toml`, so the matching private key must be available on your workstation.

At this point the Fedora bootc VM should be running on Proxmox.
