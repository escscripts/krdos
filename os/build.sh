#!/usr/bin/env bash
set -eu
# pipefail is bash-specific; enable if supported
set -o pipefail 2>/dev/null || true

# KrdOS image build (Buildroot + Flutter shell)
# Intended to run on Linux (WSL2 Ubuntu is fine).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS_DIR="${ROOT_DIR}/os"

# Allow building outputs outside /mnt/c (recommended for WSL stability/perf).
# Example:
#   export KRDOS_OUT="$HOME/krdos-out"
#   bash os/build.sh
OUT_DIR="${KRDOS_OUT:-${OS_DIR}/out}"
BR_DIR="${OUT_DIR}/buildroot-src"
BR_OUT="${OUT_DIR}/buildroot"
OVERLAY_DIR="${OS_DIR}/overlay"

echo "[1/5] Preparing folders…"
mkdir -p "${OUT_DIR}"

echo "[2/5] Building Flutter Linux release…"
cd "${ROOT_DIR}"
if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH. Install Flutter inside this Linux environment." >&2
  exit 1
fi

flutter config --enable-linux-desktop >/dev/null
flutter build linux --release

FLUTTER_BUNDLE="${ROOT_DIR}/build/linux/x64/release/bundle"
if [[ ! -d "${FLUTTER_BUNDLE}" ]]; then
  echo "Flutter bundle not found at ${FLUTTER_BUNDLE}" >&2
  exit 1
fi

echo "[3/5] Staging Flutter bundle into rootfs overlay…"
mkdir -p "${OVERLAY_DIR}/opt/krdos"
rsync -a --delete "${FLUTTER_BUNDLE}/" "${OVERLAY_DIR}/opt/krdos/"

# systemd enable: use real symlinks (overlay text files won't work)
mkdir -p "${OVERLAY_DIR}/etc/systemd/system/multi-user.target.wants"
ln -sf ../weston.service "${OVERLAY_DIR}/etc/systemd/system/multi-user.target.wants/weston.service"
ln -sf ../krdos.service  "${OVERLAY_DIR}/etc/systemd/system/multi-user.target.wants/krdos.service"

echo "[4/5] Fetching Buildroot (if needed)…"
if [[ ! -d "${BR_DIR}/.git" ]]; then
  git clone --depth 1 https://github.com/buildroot/buildroot.git "${BR_DIR}"
fi

echo "[5/5] Building Buildroot image…"
mkdir -p "${BR_OUT}"
cd "${BR_DIR}"

# Buildroot rejects PATH entries with spaces (WSL often injects Windows paths).
# Use a minimal Linux-only PATH for the Buildroot build.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

make O="${BR_OUT}" BR2_EXTERNAL="${OS_DIR}/buildroot" krdos_x86_64_defconfig
make O="${BR_OUT}" -j"$(nproc)"

echo
echo "Build complete."
echo "- Images: ${BR_OUT}/images/"
ls -1 "${BR_OUT}/images" || true
