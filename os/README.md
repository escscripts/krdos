## KrdOS (Linux image + Flutter shell)

This folder scaffolds a **bootable Linux image** that autostarts the **KrdOS Flutter UI** as the main shell.

### What this does

- Builds your Flutter app for Linux (`flutter build linux --release`)
- Builds a Linux userspace + kernel via **Buildroot**
- Adds a rootfs overlay that:
  - starts **Weston** (Wayland compositor)
  - runs your Flutter binary fullscreen at boot

### Why Buildroot (first)

Buildroot is a practical “appliance OS” builder: kernel + rootfs + packages into one reproducible output. It’s a good first step before Yocto.

### Host requirements

Because you’re on Windows, run the build inside **WSL2 Ubuntu** (recommended).

- WSL2 Ubuntu 22.04/24.04
- Packages (inside WSL):
  - `sudo apt update`
  - `sudo apt install -y build-essential git rsync file bc bison flex libssl-dev libelf-dev python3 unzip cpio`
  - For Flutter Linux build inside WSL you also need the usual Linux desktop deps (GTK), see Flutter docs for Linux desktop.

### Quick start (QEMU x86_64)

From **WSL** at the repo root (mounted under `/mnt/c/...`):

```bash
cd /mnt/c/Users/meeru/Desktop/Custom_OS/custom_os_ui
bash os/build.sh
```

If the build succeeds you’ll get an image under:

- `os/out/buildroot/images/`
  - `bzImage`
  - `rootfs.ext2`

Run it in QEMU (inside WSL):

```bash
qemu-system-x86_64 \
  -m 2048 \
  -kernel os/out/buildroot/images/bzImage \
  -drive file=os/out/buildroot/images/rootfs.ext2,format=raw \
  -append "root=/dev/sda console=ttyS0 quiet" \
  -nographic
```

### Porting to your real device

You will replace:

- **kernel config / defconfig** (device drivers)
- **Buildroot defconfig** (toolchain + packages)
- potentially **bootloader** (U-Boot/UEFI) and partitioning

Start by telling me your target:

- CPU arch: `x86_64` or `arm64`
- GPU: Intel/AMD/NVIDIA, or ARM Mali/VideoCore/etc.
- display: HDMI/eDP, touch, etc.

