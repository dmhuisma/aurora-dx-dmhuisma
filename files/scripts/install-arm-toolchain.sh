#!/usr/bin/env bash
set -euo pipefail

TOOLCHAIN_VERSION="15.3.rel1"
ARCHIVE="arm-gnu-toolchain-${TOOLCHAIN_VERSION}-x86_64-arm-none-eabi.tar.xz"
DOWNLOAD_URL="https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages/generic/gnu-toolchain/${TOOLCHAIN_VERSION}/${ARCHIVE}"
INSTALL_DIR="/opt/arm-gnu-toolchain"

echo "==> Installing ARM GNU Toolchain ${TOOLCHAIN_VERSION}..."

curl -L --progress-bar "${DOWNLOAD_URL}" -o "/tmp/${ARCHIVE}"
mkdir -p "${INSTALL_DIR}"
tar -xJf "/tmp/${ARCHIVE}" --strip-components=1 -C "${INSTALL_DIR}"
rm -f "/tmp/${ARCHIVE}"

cat > /etc/profile.d/arm-gnu-toolchain.sh << 'EOF'
export PATH="/opt/arm-gnu-toolchain/bin:${PATH}"
EOF

echo "==> ARM GNU Toolchain ${TOOLCHAIN_VERSION} installed to ${INSTALL_DIR}"
