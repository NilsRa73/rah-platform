# RAH OS Raven v0.2 Desktop Candidate

RAH OS is an experimental Debian-based desktop distribution for the RAH/Raven ecosystem.

## v0.2 Desktop Candidate

- Debian 13 `trixie` amd64 base
- KDE Plasma desktop
- black/gold RAH visual defaults
- common Wi-Fi/graphics firmware
- Python, Node.js, Git, Podman and system tools
- local Raven agent on `127.0.0.1:18765`
- RAH Command Center desktop shortcut
- **RAH Hardware Check** desktop shortcut
- read-only Live USB acceptance diagnostics for boot mode, storage, network, display, GPU, audio, Bluetooth, USB and battery
- one-click JSON hardware report download
- GitHub Actions ISO build and validation

The Raven service in v0.2 remains deliberately **local and unprivileged**. The new diagnostics are read-only and are designed to let a user validate a live USB session without opening Terminal.

## Live USB acceptance goal

Boot RAH OS from USB and confirm from the GUI:

1. KDE desktop appears and the RAH black/gold theme loads.
2. Raven Command Center reports `Raven Core online`.
3. RAH Hardware Check can inspect the machine without Terminal.
4. Network, graphics/display, audio, Bluetooth and USB devices are visible as expected.
5. A hardware report can be downloaded for later debugging.

Do **not** overwrite the internal Lenovo SSD until the live USB acceptance checks are satisfactory.

## Build model

The canonical build is `.github/workflows/build-rah-os.yml`. It uses Debian live-build and publishes the ISO plus SHA-256 checksum as a workflow artifact. Pull requests touching `rah-os/**` also run source validation and an ISO build before merge.

## Safety model

v0.2 does **not** add the future authenticated privilege broker. Raven has no endpoint for package installation, disk formatting, privileged shell execution or arbitrary system writes. Those remain separate future milestones.
