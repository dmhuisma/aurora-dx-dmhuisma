#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
set -oue pipefail

# Install keychron_battery kernel module (exposes Keychron mouse battery via
# power_supply/UPower). Upstream ships it as an Arch DKMS package; DKMS can't
# write to the read-only /usr on an image-based system, so build it here.
# Autoloads via its HID modalias when a supported mouse is connected.

KEYCHRON_BATTERY_VERSION="v0.1.2"

KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

### Install kernel headers matching the target kernel
if [[ ! -d "/usr/src/kernels/${KERNEL}" ]]; then
    dnf -y install "kernel-devel-${KERNEL}"
fi

### Build kmod from upstream source
git clone --depth=1 --branch "${KEYCHRON_BATTERY_VERSION}" https://github.com/csutcliff/keychron-battery-dkms /tmp/keychron-battery
cd /tmp/keychron-battery
make -C "/usr/src/kernels/${KERNEL}" M="$(pwd)" modules

### Install kmod
KMOD_DIR="/usr/lib/modules/${KERNEL}/extra/keychron-battery"
mkdir -p "${KMOD_DIR}"
install -m 0644 keychron_battery.ko "${KMOD_DIR}/"
depmod -a "${KERNEL}"

### Verify
modinfo "${KMOD_DIR}/keychron_battery.ko" || { echo "keychron_battery kmod verification failed"; exit 1; }

### Cleanup build artifacts
cd /
rm -rf /tmp/keychron-battery
