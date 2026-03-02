#!/usr/bin/env bash
set -euo pipefail

# SEGGER requires accepting the EULA; the POST body below automates that.
# If SEGGER changes their download mechanism, obtain JLink_Linux_x86_64.rpm
# manually from https://www.segger.com/downloads/jlink/ and place it
# alongside this script, then replace the wget block with:
#   rpm -i "$(dirname "$0")/JLink_Linux_x86_64.rpm"

echo "==> Installing JLink..."
wget -q \
    --post-data='accept_license_agreement=accepted&non_emb_ctr=confirmed&submit=Download+software' \
    'https://www.segger.com/downloads/jlink/JLink_Linux_x86_64.rpm' \
    -O /tmp/JLink_Linux_x86_64.rpm
rpm -i /tmp/JLink_Linux_x86_64.rpm
rm -f /tmp/JLink_Linux_x86_64.rpm

cat > /etc/profile.d/jlink.sh << 'EOF'
# JLink is installed to /opt/SEGGER/JLink by SEGGER's RPM.
[ -d "/opt/SEGGER/JLink" ] && export PATH="/opt/SEGGER/JLink:${PATH}"
EOF
