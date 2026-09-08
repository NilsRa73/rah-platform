# RAH OS Raven v0.1 — Windows USB test

## Safety gate

This procedure is for a **USB live-boot test only**.

- Do **not** install RAH OS to the Lenovo internal SSD/NVMe yet.
- `RAH-OS-USB-Prep` never enumerates, formats, selects, or writes to disks.
- Rufus is the only program that writes the ISO to the USB memory stick.
- In Rufus, verify the selected Device is the **USB memory stick**, never the internal SSD/NVMe.

## Files

Expected ISO:

`RAH-OS-Raven-v0.1-amd64.iso`

Expected checksum file:

`RAH-OS-Raven-v0.1-amd64.iso.sha256`

Keep both files in the same folder.

## 1. Download the build

Open the successful **Build RAH OS ISO** workflow run in GitHub Actions and download the artifact:

`RAH-OS-Raven-v0.1-amd64`

Unzip it to a normal Windows folder.

## 2. Verify the ISO in Windows

From the repository's `tools/windows` folder, double-click:

`RAH-OS-USB-Prep.cmd`

Then:

1. Click **Velg ISO...**.
2. Select `RAH-OS-Raven-v0.1-amd64.iso`.
3. Click **Verifiser SHA-256**.
4. Continue only when the window shows **PASS**.

The verifier reads the adjacent `.sha256` file and computes SHA-256 locally. It does not touch any disk device.

## 3. Create the USB with Rufus

After checksum PASS, click **Åpne Rufus** or open Rufus yourself.

In Rufus:

1. **Device:** select only the USB memory stick you intend to erase.
2. **Boot selection:** select `RAH-OS-Raven-v0.1-amd64.iso`.
3. Leave normal recommended Rufus settings unless the Lenovo requires otherwise.
4. Click **Start**.
5. Read the confirmation carefully and confirm that only the USB memory stick will be overwritten.

The USB stick will be erased. The internal SSD/NVMe must not be selected.

## 4. Boot the Lenovo from USB

1. Leave the completed RAH OS USB inserted.
2. Restart the Lenovo.
3. Open Lenovo's boot menu, normally **F12** or the **Novo** button/menu depending on the model.
4. Select the USB device.
5. Boot RAH OS in live mode.

## 5. v0.1 acceptance check

The first USB test is successful when:

- the machine boots from the USB without modifying Windows,
- the RAH OS desktop starts,
- **RAH Command Center** is visible/available as the primary experience,
- keyboard, mouse/touchpad, display and networking can be checked,
- the machine can shut down or restart cleanly back into Windows.

## Stop gate

After the live test, stop there. **Do not install to the Lenovo SSD/NVMe yet.** SSD installation is a separate gate after the USB build has been verified on the real Lenovo hardware.
