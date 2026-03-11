# Dev Container Features: malfter-devk

A collection of [Dev Container Features](https://containers.dev/implementors/features/) published to GitHub Container Registry (GHCR).

## Features

### `opencode`

Installs the [opencode](https://opencode.ai) CLI — an AI coding agent for the terminal.

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/malfter-devk/devcontainers-features/opencode:1": {}
    }
}
```

To install a specific version:

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/malfter-devk/devcontainers-features/opencode:1": {
            "version": "1.2.23"
        }
    }
}
```

#### Options

| Option    | Type   | Default    | Description                                                                 |
|-----------|--------|------------|-----------------------------------------------------------------------------|
| `version` | string | `"latest"` | Version of opencode to install. Use `"latest"` or a semver string like `"1.2.23"`. |

#### Supported Platforms

| OS                | Supported |
|-------------------|-----------|
| Debian            | yes       |
| Ubuntu            | yes       |
| OpenSUSE Leap     | yes       |
| SLES              | yes       |
| Other Linux       | yes (fallback) |

| Architecture | Supported |
|--------------|-----------|
| x86_64       | yes       |
| arm64        | yes       |

## Repository Structure

```
├── src/
│   └── opencode/
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
└── test/
    └── opencode/
        ├── scenarios.json
        ├── test.sh
        └── *.sh
```

## Publishing

Features are published to GHCR via the [release workflow](.github/workflows/release.yaml).

> **Note:** Enable *Allow GitHub Actions to create and approve pull requests* under `Settings > Actions > General > Workflow permissions` for automatic `README.md` generation per Feature.

To publish, trigger the `release` workflow manually on the `main` branch. Each Feature is versioned according to the `version` field in its `devcontainer-feature.json`.

## License

MIT
