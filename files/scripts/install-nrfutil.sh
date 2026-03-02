#!/usr/bin/env bash
set -euo pipefail

# nrfutil is Nordic's unified CLI, replacing the deprecated nrfjprog.
# The `device` plugin provides nRF52 flashing and debugging.
# https://www.nordicsemi.com/Products/Development-tools/nRF-Util

echo "==> Installing nrfutil..."
curl -sL \
    "https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/x86_64-unknown-linux-gnu/nrfutil" \
    -o /usr/local/bin/nrfutil
chmod +x /usr/local/bin/nrfutil

echo "==> Installing nrfutil device plugin..."
NRFUTIL_HOME=/opt/nrfutil nrfutil install device

cat > /etc/profile.d/nrfutil.sh << 'EOF'
export NRFUTIL_HOME="/opt/nrfutil"
EOF
