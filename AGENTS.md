# AGENTS.md — context for maintainers & AI agents

## What this is

Scripts + docs that turn a Raspberry Pi (verified: Pi 1 Model B Rev 2,
512 MB, Raspberry Pi OS Lite 32-bit Trixie) into a LAN print server for
**HP LaserJet 1020**.

## Key technical facts (don't relearn the hard way)

- LJ1020 is host-based: firmware `sihp1020.dl` must be pushed into the
  printer **on every power-on**. Driver = **foo2zjs** (`printer-driver-foo2zjs`
  + `-common`). **hplip does NOT support LJ1020.**
- `getweb 1020` (from `-common`, root-only, in `/usr/sbin`) downloads
  `sihp1020.img`, converts via `arm2hpdl` → `/lib/firmware/hp/sihp1020.dl`.
  The packaged udev hook `/lib/udev/hplj1020` (triggered by
  `85-hplj10xx.rules`, RUN+="hplj1020") reads it from `/lib/firmware/hp`
  and uploads via the CUPS usb backend. We also copy the .dl to
  `/var/lib/foo2zjs/firmware` and `/usr/share/foo2zjs/firmware` —
  the loader's FWDIR differs across distro builds; cheap insurance.
- PPD comes from the dynamic generator `/usr/lib/cups/driver/foo2zjs` —
  pick it via `lpinfo -m | grep -i 1020` (string like
  `foo2zjs:0/ppd/foo2zjs/HP-LaserJet_1020.ppd`).
- USB id of LJ1020: `03f0:2b17`. Firmware-loaded check: `FWVER` in
  `sudo /usr/lib/cups/backend/usb` output (no `usblp`/`/dev/usb/lp*` needed).
- CUPS LAN access: `Port 631` (not `Listen localhost:631`) + `Allow @LOCAL`
  inside `<Location>` blocks + `lpadmin -o printer-is-shared=true` +
  `cupsctl --share-printers --remote-admin`. Web UI needs
  `cupsctl WebInterface=yes` (off by default).
- Clients should send formats the server can rasterize. Windows: add by
  `http://HOST:631/printers/HP1020` URL with a **PostScript** driver
  (Microsoft PS Class Driver). Linux: `-m everywhere` IPP queue.
  The native HP 1020 driver does not work over IPP.

## First-boot provisioning (Trixie specifics)

- `userconf`/`userconf.txt` in bootfs (line `user:sha512crypt`) is
  **required headless** — without it `userconfig.service` hangs boot in an
  interactive wizard on tty8.
- Empty `ssh` file in bootfs → `sshswitch.service` enables sshd.
- The stock image already contains user `pi` (uid 1000, nologin);
  userconf-service renames/re-enables it, `usermod -s /bin/bash` needed
  if provisioning manually.

## Hardware lessons (verified by failure)

- **Weak PSU kills SD cards**: undervoltage during heavy `apt` write load
  → I/O errors → rootfs remounts read-only → broken system. Use ≥2 A.
- The printer must be **powered on** when the queue is created —
  `lpinfo -v` shows no USB URI otherwise. Script is idempotent, re-run.
- Rendering a page on ARMv6 700 MHz takes ~30-60 s — slow is normal.

## Conventions

- Shell: `bash`, `set -euo pipefail`, idempotent, comment-heavy (the users
  are beginners).
- Docs (`docs/`) are in Russian; code/README in English.
- `images/` holds downloaded OS images — gitignored.

## Verify changes

- `bash -n scripts/*.sh` for syntax.
- On a live Pi: `sudo bash scripts/setup-print-server.sh` (idempotent),
  then `lp -d HP1020 /usr/share/cups/data/testprint`, watch
  `journalctl | grep -i hplj` for firmware uploads.
