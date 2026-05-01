#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/opt/arm-gnu-toolchain"
DOWNLOADS_PAGE="https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads"

echo "==> Fetching latest ARM GNU Toolchain version..."
LATEST_VERSION=$(curl -s "${DOWNLOADS_PAGE}" \
    | grep -oP 'arm-gnu-toolchain-\K[0-9]+\.[0-9]+\.rel[0-9]+' \
    | sort -V | tail -1)

if [[ -z "${LATEST_VERSION}" ]]; then
    echo "ERROR: Could not determine latest ARM GNU Toolchain version" >&2
    exit 1
fi

echo "==> Installing ARM GNU Toolchain ${LATEST_VERSION}..."

ARCHIVE="arm-gnu-toolchain-${LATEST_VERSION}-x86_64-arm-none-eabi.tar.xz"
DOWNLOAD_URL="https://developer.arm.com/-/media/Files/downloads/gnu/${LATEST_VERSION}/binrel/${ARCHIVE}"

curl -L --progress-bar "${DOWNLOAD_URL}" -o "/tmp/${ARCHIVE}"
mkdir -p "${INSTALL_DIR}"
tar -xJf "/tmp/${ARCHIVE}" --strip-components=1 -C "${INSTALL_DIR}"
rm -f "/tmp/${ARCHIVE}"

cat > /etc/profile.d/arm-gnu-toolchain.sh << 'EOF'
export PATH="/opt/arm-gnu-toolchain/bin:${PATH}"
EOF

echo "==> ARM GNU Toolchain ${LATEST_VERSION} installed to ${INSTALL_DIR}"
