# RAH OS 0.9: installed-session preflight

The existing Live USB acceptance requires `boot=live`. An installed VirtualBox
guest does not normally have this parameter. Use the separate preflight scope
to check that guest without treating it as a failed USB boot:

```sh
python3 /usr/local/bin/rah-live-acceptance --installed --gui
```

This option is available only in builds containing this change. It is not
automatically installed into an existing OMEN VM. Confirm the actual guest
identity first; plain Debian without `/etc/rah-os-release` remains FAIL rather
than being relabelled RAH OS 0.9.

The utility reads the release marker, GUI environment, local Raven health and
diagnostics, and existing Raven service state. It saves one JSON report under
Downloads with the prefix `RAH-OS-INSTALLED-PREFLIGHT`. `--no-save` skips that
write. It does not change settings, start services, install packages or run
model inference. No root privileges are needed.

Installed-session PASS means only that the required checks in this session
passed. It never establishes physical OMEN hardware support, successful
reboot/login, browser operation, model inference or eligibility for Stable.
The report has a separate schema and always sets `eligible_for_review=false`.
The default Live USB acceptance retains its existing boot requirement.

Before applying any later update to OMEN, collect read-only identity evidence
and take a VirtualBox snapshot so rollback is available. Deployment and VM
testing of this change are NOT TESTED. No new ISO was built for this change.

Validation:

```sh
python3 -m unittest discover -s rah-os/tests -p 'test_installed_preflight.py' -v
python3 rah-os/config/includes.chroot/usr/local/bin/rah-live-acceptance --self-test
```
