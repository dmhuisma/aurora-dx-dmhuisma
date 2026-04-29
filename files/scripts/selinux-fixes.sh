#!/usr/bin/env bash

set -oue pipefail

# swtpm is incorrectly labeled bin_t instead of swtpm_exec_t at image build time,
# because the SELinux policy file context entry for swtpm is missing or not matched
# during rpm-ostree installation. This adds a persistent custom rule and relabels
# the file so the correct context is baked into the ostree commit.
semanage fcontext -a -t swtpm_exec_t /usr/bin/swtpm
restorecon -v /usr/bin/swtpm
