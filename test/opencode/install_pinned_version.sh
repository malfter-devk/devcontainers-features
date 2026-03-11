#!/bin/bash
# -----------------------------------------------------------------------------
# Scenario test: install_pinned_version
# Verifies that the 'opencode' binary is installed at exactly the requested
# pinned version (1.2.23) and not a different release.
# -----------------------------------------------------------------------------
set -e

source dev-container-features-test-lib

check "opencode binary is in PATH" \
    bash -c "command -v opencode"

check "opencode binary is executable at /usr/local/bin" \
    bash -c "test -x /usr/local/bin/opencode"

check "opencode --version returns a version string" \
    bash -c "opencode --version 2>&1 | grep -E '[0-9]+\.[0-9]+\.[0-9]+'"

check "opencode is installed at the pinned version 1.2.23" \
    bash -c "opencode --version 2>&1 | grep -F '1.2.23'"

reportResults
