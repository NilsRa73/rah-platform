# RAH OS Raven v0.1

RAH OS is an experimental Debian-based desktop distribution for the RAH/Raven ecosystem.

## v0.1 foundation

- Debian 13 `trixie` amd64 base
- KDE Plasma desktop
- black/gold RAH visual defaults
- common Wi-Fi/graphics firmware
- Python, Node.js, Git, Podman and system tools
- local Raven agent on `127.0.0.1:18765`
- RAH Command Center desktop shortcut
- GitHub Actions ISO build

The Raven service in v0.1 is deliberately **local and unprivileged**. It provides health/system information and the first Command Center shell. A later milestone adds an authenticated privilege broker for approved system actions.

## Build model

The canonical build is `.github/workflows/build-rah-os.yml`. It uses Debian live-build and publishes the ISO plus SHA-256 checksum as a workflow artifact.

## Safety model

The first image is intended for USB testing. Do not overwrite the Lenovo SSD until hardware, networking, boot, Raven service and desktop behavior have been validated.
