
# opencode (opencode)

Installs the opencode CLI — an AI coding agent for the terminal.

## Example Usage

```json
"features": {
    "ghcr.io/malfter-devk/devcontainers-features/opencode:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of opencode to install. Use 'latest' for the latest stable release, or a semver string like '1.2.24'. | string | latest |

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

## Recommended Mounts

opencode stores its configuration, sessions, and API keys in `~/.config/opencode/` on Linux.
Mount this directory from the host so that your sessions and settings persist across container rebuilds:

```jsonc
"mounts": [
  // The target paths below use /home/vscode, which is the home directory of the default
  // devcontainer user. Adjust this to match the remoteUser or containerUser configured
  // in your devcontainer.json (e.g. /root for a root-based container).
  "source=${localEnv:HOME}/.config/opencode,target=/home/vscode/.config/opencode,type=bind,consistency=cached",
  "source=${localEnv:HOME}/.local/share/opencode,target=/home/vscode/.local/share/opencode,type=bind",
  "source=${localEnv:HOME}/.local/state/opencode,target=/home/vscode/.local/state/opencode,type=bind",
]
```

## Recommended VS Code Settings

Add this to your `.devcontainer/devcontainer.json` (via `customizations.vscode.settings`) or your local `settings.json`:

```jsonc
// Let Ctrl+P pass through to terminal apps (e.g. opencode)
// instead of opening VS Code Quick Open when the terminal has focus.
"terminal.integrated.commandsToSkipShell": ["-workbench.action.quickOpen"]
```


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/malfter-devk/devcontainers-features/blob/main/src/opencode/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
