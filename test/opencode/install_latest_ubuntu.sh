#!/bin/bash
# -----------------------------------------------------------------------------
# Scenario test: install_latest_ubuntu
# Verifies that the 'opencode' binary was installed correctly on Ubuntu.
# -----------------------------------------------------------------------------
set -e

source dev-container-features-test-lib

check "opencode binary is in PATH" \
    bash -c "command -v opencode"

check "opencode --version returns a version" \
    bash -c "opencode --version 2>&1 | grep -E '[0-9]+\.[0-9]+\.[0-9]+'"

check "opencode binary is executable at /usr/local/bin" \
    bash -c "test -x /usr/local/bin/opencode"

# Verify we are actually running on Ubuntu
check "running on Ubuntu" \
    bash -c "grep -qiE '^ID=ubuntu' /etc/os-release"

reportResults
