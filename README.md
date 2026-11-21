# raspberry-pi1-print-server

Turn a **HP LaserJet 1020** USB printer into a network printer using a
**Raspberry Pi 1 Model B** (yes, the original 700 MHz ARMv6 board with
512 MB RAM — plenty for a print server).

> 🇷🇺 Подробная пошаговая документация на русском — в каталоге [`docs/`](docs/).

## Why this project is non-trivial

The LaserJet 1020 is a *host-based* printer: it has **no firmware in
permanent memory**. The firmware blob (`sihp1020.dl`) must be uploaded to
the printer **every time it is powered on**, or it just sits there
silently. This project handles that automatically:

- `foo2zjs` driver (the only working option — hplip does **not** support LJ1020)
- firmware auto-upload via udev whenever the printer powers on or is plugged in
- network printing for the whole LAN via **CUPS** (IPP, TCP :631)
- **avahi/mDNS** announcement — clients discover the printer automatically

## Hardware

| Component | Notes |
|---|---|
| Raspberry Pi 1 B (Rev 2, 512 MB) | works on any other Pi too |
| microSD card ≥ 8 GB | a decent one — cheap cards fail under write load |
| **Power supply ≥ 1.5–2 A** | **important** — a weak PSU causes SD card corruption |
| Ethernet cable to the router | Pi 1 has no Wi-Fi (a USB Wi-Fi dongle works too) |
| HP LaserJet 1020 + USB cable | — |

## Software

Raspberry Pi OS Lite (32-bit), CUPS, `printer-driver-foo2zjs`, avahi.
Everything is installed and configured by one script.

## Quick start

```bash
# 1. Flash Raspberry Pi OS Lite (32-bit) to the SD card
#    (see docs/01-flash-sd.md for a full walk-through)

# 2. Boot the Pi, copy the scripts over, run the installer:
scp -r scripts pi@printserver.local:~/
ssh pi@printserver.local 'cd ~/scripts && sudo bash setup-print-server.sh'

# 3. Power on the printer — firmware uploads automatically
#    (~5 s of orange blinking). Then a test page:
ssh pi@printserver.local 'lp -d HP1020 /usr/share/cups/data/testprint'
```

Printer URL for clients: **`http://printserver.local:631/printers/HP1020`**

## Adding clients

- **Windows 10/11** — Add printer → "shared printer by name" → the URL above,
  driver **Microsoft PS Class Driver** (CUPS does the conversion on the Pi;
  the stock HP 1020 driver does not work over IPP)
- **Linux** — `lpadmin -p HP1020 -E -v ipp://printserver.local:631/printers/HP1020 -m everywhere`,
  or just pick it from printer settings (mDNS discovery)
- **Android** — built-in print service or Mopria (IPP)
- **macOS / iOS** — works via CUPS Bonjour announcement

Detailed per-OS instructions (in Russian): [`docs/03-clients.md`](docs/03-clients.md).

## Repository layout

```
scripts/setup-print-server.sh   # one-shot setup: CUPS, foo2zjs, firmware, sharing
scripts/load-firmware.sh        # manual firmware upload (if udev didn't fire)
scripts/diagnostics.sh          # collects debug info when things go wrong
docs/                           # step-by-step guides (Russian)
```

## Caveats & gotchas

- Firmware must be re-uploaded **every time** the printer powers on —
  the udev rule handles it, but if it didn't, run `sudo bash load-firmware.sh`.
- Pi 1 + weak power supply = corrupted SD card under load. Use a solid PSU.
- Rendering on a 700 MHz ARMv6 takes 30–60 s per page — be patient.
- Reserve the Pi's IP in your router (or rely on `printserver.local`).

## Contributing

Issues and PRs are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
