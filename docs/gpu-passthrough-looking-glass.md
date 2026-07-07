# GPU Passthrough with virt-manager and Looking Glass

This image bakes in everything that *can* be baked into an atomic image for VFIO GPU
passthrough with [Looking Glass](https://looking-glass.io/). What remains is machine-local
state (kernel arguments, libvirt config, group membership, the VM itself) that rpm-ostree
deliberately keeps out of the image. This document lists both: what the image already
provides, and the one-time manual steps to perform on each machine.

## What the image already provides

Baked in by [`files/scripts/kvmfr_and_vfio.sh`](../files/scripts/kvmfr_and_vfio.sh):

- The **kvmfr kernel module**, built from the Looking Glass **B7** branch at image build
  time, loaded at boot via `modules-load.d`, with `static_size_mb=256` set in `modprobe.d`.
  This creates `/dev/kvmfr0` — the shared-memory device Looking Glass uses instead of a
  plain shm file.
- A **udev rule** setting `/dev/kvmfr0` to `root:incus-admin`, mode `0660`.
- A **dracut config** that includes the `vfio`, `vfio_iommu_type1` and `vfio-pci` drivers
  in the initramfs, so the GPU can be claimed before any display driver sees it.
- `/etc/looking-glass-client.ini` pre-configured with `shmFile=/dev/kvmfr0`.
- A **compiled SELinux policy module** at `/etc/kvmfr/selinux/pp/kvmfr.pp` that allows
  qemu (`svirt_t`) to use the kvmfr device. **Shipped but not installed** — installing
  it at image build time does not persist, so this is a manual step below.
- `/usr/libexec/vfio-kargs.sh`, a helper that appends the IOMMU/VFIO kernel arguments
  for your CPU vendor. Also a manual step below — nothing runs it automatically.

From the aurora-dx base image:

- The full virtualization stack: `virt-manager`, `virsh`, libvirt/qemu with the modular
  daemons (`virtqemud`).

From the `-personal` variant ([`recipes/modules/personal-dev.yml`](../recipes/modules/personal-dev.yml)):

- The build dependencies for the Looking Glass **client** (`spice-protocol`,
  `nettle-devel`, `pipewire-devel`, `libsamplerate-devel`, cmake, etc.). The client
  binary itself is built in userspace — see step 5.

> [!NOTE]
> The host should not be using the GPU you intend to pass through. If the passthrough
> GPU is your only NVIDIA card, use a **non-nvidia** image variant so no NVIDIA driver
> competes for it; the host runs on the iGPU or another card.

## One-time manual setup (per machine)

### 1. Identify the GPU

Find the PCI address and vendor:device IDs of the GPU, including **every function** on
it (desktop cards usually have an audio function alongside the video function):

```bash
lspci -nn | grep -iE 'vga|3d|audio.*nvidia|nvidia'
```

Example output — the IDs are the `[vvvv:dddd]` pairs at the end:

```
01:00.0 VGA compatible controller [0300]: NVIDIA ... [10de:2504]
01:00.1 Audio device [0403]: NVIDIA ... [10de:228e]
```

Also confirm the GPU is cleanly isolated in its own IOMMU group (only the GPU's own
functions should appear):

```bash
for g in /sys/kernel/iommu_groups/*/devices/*; do echo "group ${g#*groups/}"; done | sort -V
```

### 2. Apply kernel arguments and bind the GPU to vfio-pci

Run the shipped helper (adds `intel_iommu=on`/`amd_iommu=on`, `iommu=pt`,
`rd.driver.pre=vfio_pci`, `vfio_pci.disable_vga=1`), then add your GPU's IDs — all
functions, comma-separated — and blacklist the host driver for that card (`nouveau`
and/or `nvidia`):

```bash
sudo /usr/libexec/vfio-kargs.sh
sudo rpm-ostree kargs \
  --append-if-missing=vfio_pci.ids=10de:xxxx,10de:yyyy \
  --append-if-missing=modprobe.blacklist=nouveau
systemctl reboot
```

The blacklist is required, not optional: the base image ships a prebuilt initramfs
without the vfio drivers, so the image instead loads `vfio-pci` at boot via
`modules-load.d`, *after* udev has probed devices. The `vfio_pci.ids` argument tells it
which devices to claim when it loads, but a display driver that isn't blacklisted would
have grabbed the GPU first.

After the reboot, verify vfio-pci owns the GPU:

```bash
lspci -nnk -s 01:00.0   # "Kernel driver in use: vfio-pci"
```

Two failure modes:

- **Another driver in use** — the blacklist didn't cover it (e.g. `nvidia` on the
  nvidia image variants); blacklist that driver too.
- **No "Kernel driver in use" line at all** — the vfio-pci module never loaded. Images
  built before the `modules-load.d/vfio-pci.conf` fix don't load it automatically; run
  `sudo modprobe vfio-pci` to bind immediately, and
  `echo vfio-pci | sudo tee /etc/modules-load.d/vfio-pci.conf` to persist until you
  rebase onto a fixed build.

Kernel arguments survive image updates; this is done once per machine.

### 3. Install the SELinux policy module

The compiled policy ships in the image but must be installed into the machine-local
policy store (this persists across image updates):

```bash
sudo semodule -i /etc/kvmfr/selinux/pp/kvmfr.pp
semodule -l | grep kvmfr   # verify
```

### 4. Give qemu and your user access to /dev/kvmfr0

Two processes need to open the device: the qemu process running the VM, and your
Looking Glass client.

```bash
# your user (LG client) — aurora-dx's `ujust dx-group` normally covers this
sudo usermod -aG incus-admin,libvirt "$USER"

# the qemu user (VM process)
sudo usermod -aG incus-admin qemu
```

libvirt also confines device access via a cgroup allowlist. Edit
`/etc/libvirt/qemu.conf`, uncomment `cgroup_device_acl` and append `/dev/kvmfr0` to the
default list:

```
cgroup_device_acl = [
    "/dev/null", "/dev/full", "/dev/zero",
    "/dev/random", "/dev/urandom",
    "/dev/ptmx", "/dev/kvm",
    "/dev/userfaultfd", "/dev/kvmfr0"
]
```

Then restart the daemon: `sudo systemctl restart virtqemud`.

### 5. Build the Looking Glass client

All build dependencies are in the `-personal` image. Build from the **B7 tag** so the
client matches the kvmfr module baked into the image (Looking Glass requires host app,
client and module to be the same release):

```bash
git clone --recursive --branch B7 https://github.com/gnif/LookingGlass ~/src/LookingGlass
cmake -S ~/src/LookingGlass/client -B ~/src/LookingGlass/client/build
cmake --build ~/src/LookingGlass/client/build -j"$(nproc)"
install -Dm755 ~/src/LookingGlass/client/build/looking-glass-client ~/.local/bin/
```

No client-side shm configuration is needed — `/etc/looking-glass-client.ini` already
points at `/dev/kvmfr0`.

### 6. Configure the VM

Create the VM in virt-manager (or import an existing definition with `virsh define`),
then make sure the domain XML has:

- A `<hostdev>` entry for **each function** of the GPU found in step 1.
- The kvmfr shared-memory device. libvirt has no native syntax for kvmfr, so it goes in
  a `<qemu:commandline>` block — note the required `xmlns:qemu` attribute on `<domain>`,
  and the size in bytes must match the module's `static_size_mb=256`
  (256 MiB = 268435456):

```xml
<domain xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0' type='kvm'>
  ...
  <qemu:commandline>
    <qemu:arg value='-device'/>
    <qemu:arg value='{"driver":"ivshmem-plain","id":"shmem0","memdev":"looking-glass"}'/>
    <qemu:arg value='-object'/>
    <qemu:arg value='{"qom-type":"memory-backend-file","id":"looking-glass","mem-path":"/dev/kvmfr0","size":268435456,"share":true}'/>
  </qemu:commandline>
</domain>
```

If you already have a `<shmem>` device from a non-kvmfr setup, remove it — the
`qemu:commandline` block replaces it.

When importing a VM definition from another machine, also update:

- the disk path (copy the disk image to a storage pool such as
  `/var/lib/libvirt/images/` and run `restorecon` on it),
- the UEFI firmware paths — current Fedora ships OVMF as
  `/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2` (older machines may reference `.fd` files),
- the `<hostdev>` PCI source addresses, which are specific to each machine.

### 7. Set up the Windows guest

Inside the VM:

- Install the Looking Glass **host application**, same release as the client (B7), and
  the **IVSHMEM driver** (both from [looking-glass.io](https://looking-glass.io/downloads)).
- Install the NVIDIA driver for the passed-through GPU.
- The GPU needs an active display for the host app to capture. Use a physical monitor or
  dummy plug on the card's output, or install a virtual display driver in Windows.

Laptop/mobile GPUs have two extra quirks: NVIDIA mobile drivers may refuse to initialize
without a battery, fixed by attaching a fake ACPI battery SSDT to the VM, and they
usually have no physical outputs, making the virtual display driver mandatory.

## Verification checklist

```bash
lspci -nnk -s <gpu-address>        # driver in use: vfio-pci
ls -l /dev/kvmfr0                  # exists, root:incus-admin, 0660
semodule -l | grep kvmfr           # policy module installed
groups | grep incus-admin          # your user has device access
```

Then start the VM and run `looking-glass-client`. If the VM starts but the client
reports a version mismatch, the guest's host app and the client were built from
different Looking Glass releases (see steps 5 and 7).
