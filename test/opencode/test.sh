#!/bin/bash
# -----------------------------------------------------------------------------
# Smoke test for the 'opencode' Dev Container Feature.
#
# This test is executed against an auto-generated devcontainer.json that
# includes the 'opencode' feature with no explicit options (i.e. defaults apply:
# version = "latest").
#
# Run manually with the devcontainer CLI:
#
#   devcontainer features test \
#     --features opencode \
#     --remote-user root \
#     --skip-scenarios \
#     --base-image mcr.microsoft.com/devcontainers/base:ubuntu \
#     /path/to/this/repo
# -----------------------------------------------------------------------------
set -e

# Import the test library bundled with the devcontainer CLI.
# Provides the 'check' and 'reportResults' helpers.
source dev-container-features-test-lib

# ---------------------------------------------------------------------------
# Test 1: Binary exists in PATH
# ---------------------------------------------------------------------------
check "opencode binary is in PATH" \
    bash -c "command -v opencode"

# ---------------------------------------------------------------------------
# Test 2: Binary is executable and returns a version string
# ---------------------------------------------------------------------------
check "opencode --version returns a version" \
    bash -c "opencode --version 2>&1 | grep -E '[0-9]+\.[0-9]+\.[0-9]+'"

# ---------------------------------------------------------------------------
# Test 3: Binary is installed at the expected location
# ---------------------------------------------------------------------------
check "opencode is installed at /usr/local/bin/opencode" \
    bash -c "test -x /usr/local/bin/opencode"

# ---------------------------------------------------------------------------
# Report all results — exits non-zero if any check failed
# ---------------------------------------------------------------------------
reportResults
