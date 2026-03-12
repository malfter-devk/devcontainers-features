
# opencode (opencode)

Installs the [opencode](https://opencode.ai) CLI — an AI coding agent for the terminal.

## Example Usage

Install the latest stable release (default):

```json
"features": {
    "ghcr.io/malfter-devk/devcontainers-features/opencode:1": {}
}
```

Install a specific version:

```json
"features": {
    "ghcr.io/malfter-devk/devcontainers-features/opencode:1": {
        "version": "1.2.3"
    }
}
```

## Options

| Option ID | Description | Type | Default Value |
|-----------|-------------|------|---------------|
| version | Version of opencode to install. Use `latest` for the latest stable release, or a semver string like `1.2.24`. | string | `latest` |

## Supported Operating Systems

| Distribution | Install Method |
|---|---|
| Debian | Binary download from GitHub Releases |
| Ubuntu | Binary download from GitHub Releases |
| OpenSUSE / SLES | Binary download from GitHub Releases |
| Other Linux | Binary download (best-effort fallback) |

## Supported Architectures

| Architecture | Asset suffix |
|---|---|
| `x86_64` (amd64) | `x64` |
| `aarch64` (arm64) | `arm64` |

## How it works

1. Detects the available HTTP client (`curl` preferred, `wget` fallback). Installs `curl` via the distro package manager if neither is present.
2. Reads the requested version from the `version` option.
   - `"latest"` → queries the GitHub Releases API (`/releases/latest`) to find the current stable release tag.
   - Any other value (e.g. `"1.2.24"`) → constructs the tag `v1.2.24` directly.
3. Downloads the `.tar.gz` archive for the detected OS/arch from GitHub Releases (`opencode-linux-{x64|arm64}.tar.gz`).
4. Extracts the `opencode` binary, installs it to `/usr/local/bin/opencode` with `chmod +x`.
5. Validates the installed version matches the requested version.

The script is **idempotent**: if the requested version is already installed it exits immediately with code 0.

## Environment Variables

| Variable | Effect |
|---|---|
| `OPENCODE_GITHUB_TOKEN` | Optional. Passed as a Bearer token to the GitHub API to avoid rate limits. Use a PAT with public repo read access. |

## Notes

- This feature requires network access to `github.com` and `api.github.com` at container build time.
- The binary is installed as `root` (the default for devcontainer feature scripts).

---

_Note: This file was generated from [devcontainer-feature.json](devcontainer-feature.json). Add additional notes to a `NOTES.md`._
