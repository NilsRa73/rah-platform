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

The Raven service in v0.2 remains deliberately **local and unprivileged**. The diagnostics are read-only and are designed to let a user validate a live USB session without opening Terminal.

## Recovery Center v1 candidate

The next RAH OS hardening layer adds **RAH Recovery Center**, available both from the KDE application menu and as a desktop shortcut.

Recovery Center is intentionally independent of the Raven web service, so it can still diagnose the machine when Raven itself is unavailable. In one run it checks:

- Raven Core health and systemd state
- UEFI vs Legacy/BIOS boot
- Live USB vs installed-style session
- Live persistence detection
- root filesystem mount state and free space
- temporary workspace write health
- incomplete `dpkg` package state
- network adapter visibility/state
- recent priority-3 boot journal entries

It then creates a prioritized repair plan and exports both:

- `RAH-Recovery-YYYYMMDD-HHMMSS.html` — black/gold human-readable report
- `RAH-Recovery-YYYYMMDD-HHMMSS.json` — machine-readable report for Raven/ChatGPT/developer analysis

Reports are saved to `~/Downloads` when writable, otherwise to the temporary directory.

### Recovery safety boundary

Recovery Center v1 is **diagnostic and advisory only**. Suggested repair commands are displayed in the report but are not executed. It does not format disks, install packages, rewrite bootloaders, erase files, or make privileged system changes.

This is deliberate: the later authenticated privilege broker can add carefully allowlisted repair actions after the read-only recovery path has proven stable on real hardware.

## Post-v0.2 hardening gate

Before the next RAH OS version is promoted, the repository validates more than syntax and ISO creation:

- `rah-os/tests/test_raven_agent.py` starts the real Raven HTTP handler on a temporary localhost port and checks `/health`, `/system`, `/api/diagnostics`, `/report`, the Command Center page and the 404 path.
- `rah-os/tests/test_recovery_center.py` validates repair-plan generation, HTML escaping, report export and the Recovery Center built-in self-test.
- `recovery-center.py --self-test` runs in CI before ISO creation.
- `rah-os/RAH-OS-USB-PREP.ps1 -SelfTest` is executed on a Windows GitHub runner.
- the ISO build does not start unless the Linux runtime tests and Windows prep self-test pass.

## Windows one-click USB preparation

From a Windows checkout or extracted RAH OS folder, double-click:

`START-HER.cmd`

It launches `RAH-OS-USB-PREP.ps1`, which is intentionally read-only. It:

1. finds the newest `RAH-OS*.iso` beside the launcher, in `output`, the current directory or Downloads;
2. computes SHA-256 and verifies a sidecar `.sha256` file when present;
3. inventories USB disks with size and status and flags any disk Windows marks as system/boot;
4. detects common flashing tools when available;
5. saves one timestamped `RAH-OS-USB-PREP-*.txt` report with the next safe action.

It never formats, partitions or writes a USB disk. The destructive flash step remains an explicit user action in Rufus, balenaEtcher or Ventoy after the target disk has been checked.

## Live USB acceptance goal

Boot RAH OS from USB and confirm from the GUI:

1. KDE desktop appears and the RAH black/gold theme loads.
2. Raven Command Center reports `Raven Core online`.
3. RAH Hardware Check can inspect the machine without Terminal.
4. RAH Recovery Center opens from the desktop/application menu and exports HTML + JSON.
5. Network, graphics/display, audio, Bluetooth and USB devices are visible as expected.
6. A hardware report can be downloaded for later debugging.

Do **not** overwrite the internal Lenovo SSD until the live USB acceptance checks are satisfactory.

## Build model

The canonical build is `.github/workflows/build-rah-os.yml`. It uses Debian live-build and publishes the ISO plus SHA-256 checksum as a workflow artifact. Pull requests touching `rah-os/**` first run Raven + Recovery runtime tests and the Windows USB-prep self-test; only then can the ISO build job start.

## Safety model

v0.2 does **not** add the future authenticated privilege broker. Raven has no endpoint for package installation, disk formatting, privileged shell execution or arbitrary system writes. Those remain separate future milestones.
