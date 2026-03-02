#!/usr/bin/env bash
set -euo pipefail

ZEPHYR_SDK_VERSION="0.17.4"

ZEPHYR_SDK_DIR="/opt/zephyr-sdk"
ZEPHYR_BASE_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}"

echo "==> Installing Zephyr SDK ${ZEPHYR_SDK_VERSION}..."
mkdir -p "${ZEPHYR_SDK_DIR}"

wget -q "${ZEPHYR_BASE_URL}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64_minimal.tar.xz" \
    -O /tmp/zephyr-sdk-minimal.tar.xz
tar -xJf /tmp/zephyr-sdk-minimal.tar.xz --strip-components=1 -C "${ZEPHYR_SDK_DIR}"

# ARM Cortex-M toolchain (arm-zephyr-eabi, covers nRF52 and other Cortex-M targets)
wget -q "${ZEPHYR_BASE_URL}/toolchain_linux-x86_64_arm-zephyr-eabi.tar.xz" \
    -O /tmp/zephyr-toolchain-arm.tar.xz
tar -xJf /tmp/zephyr-toolchain-arm.tar.xz -C "${ZEPHYR_SDK_DIR}"

# Register Zephyr SDK CMake packages (required for west build to find the SDK)
"${ZEPHYR_SDK_DIR}/setup.sh" -c

rm -f /tmp/zephyr-sdk-minimal.tar.xz /tmp/zephyr-toolchain-arm.tar.xz

echo "==> Installing west and Python build tools..."
pip3 install --break-system-packages west pyelftools

cat > /etc/profile.d/zephyr-sdk.sh << 'EOF'
export ZEPHYR_SDK_INSTALL_DIR="/opt/zephyr-sdk"
export PATH="/opt/zephyr-sdk/arm-zephyr-eabi/bin:${PATH}"
EOF
