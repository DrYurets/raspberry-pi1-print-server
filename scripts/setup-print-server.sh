#!/bin/bash
#
# setup-print-server.sh — turn a Raspberry Pi (OS Lite) into a print
# server for HP LaserJet 1020.
#
# What it does:
#   1. Installs CUPS, the foo2zjs driver and avahi (mDNS)
#   2. Downloads the printer firmware sihp1020.dl — mandatory:
#      without it the LJ1020 prints nothing, and it must be re-uploaded
#      on every printer power-on (handled automatically by udev)
#   3. Opens CUPS to the local network (IPP on port 631)
#   4. Creates the printer queue and shares it
#   5. Uploads firmware right away if the printer is already on
#
# Usage on the Pi:
#   sudo bash setup-print-server.sh
#
# Idempotent — safe to re-run.

set -euo pipefail

PRINTER_NAME="HP1020"
FW_NAME="sihp1020.dl"
FW_DIRS="/lib/firmware/hp /var/lib/foo2zjs/firmware /usr/share/foo2zjs/firmware"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run as root: sudo bash $0"
REAL_USER="${SUDO_USER:-}"

# ─── 1. Packages ────────────────────────────────────────────────────────────
step "1/6 Installing packages (slow on Pi 1, be patient)"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    cups cups-filters ghostscript \
    printer-driver-foo2zjs printer-driver-foo2zjs-common foomatic-db-engine \
    avahi-daemon wget usbutils
systemctl enable --now cups avahi-daemon
ok "Packages installed"

# ─── 2. Printer firmware ────────────────────────────────────────────────────
step "2/6 Printer firmware $FW_NAME"
if [ -f "/lib/firmware/hp/$FW_NAME" ]; then
    ok "Already present: /lib/firmware/hp/$FW_NAME"
else
    TMPD="$(mktemp -d)"
    ( cd "$TMPD" && mkdir -p /lib/firmware/hp && getweb 1020 )
    rm -rf "$TMPD"
fi
[ -f "/lib/firmware/hp/$FW_NAME" ] || die "Failed to get $FW_NAME (check internet on the Pi)"
# Copy to alternative dirs — the udev loader's FWDIR varies across builds
for d in $FW_DIRS; do
    mkdir -p "$d"
    [ -f "$d/$FW_NAME" ] || cp "/lib/firmware/hp/$FW_NAME" "$d/" 2>/dev/null || true
done
ls -l "/lib/firmware/hp/$FW_NAME"
udevadm control --reload-rules

# ─── 3. CUPS: LAN access ────────────────────────────────────────────────────
step "3/6 Configuring CUPS for LAN"
CUPSD=/etc/cups/cupsd.conf
[ -f "$CUPSD.bak" ] || cp "$CUPSD" "$CUPSD.bak"
# Listen on all interfaces, port 631
if grep -qE '^Listen[[:space:]]+localhost:631' "$CUPSD"; then
    sed -i 's/^Listen[[:space:]]\+localhost:631/Port 631/' "$CUPSD"
elif ! grep -qE '^(Port|Listen)[[:space:]]+.*:631' "$CUPSD"; then
    echo 'Port 631' >> "$CUPSD"
fi
# Allow access from the local network in every <Location> block
grep -q 'Allow @LOCAL' "$CUPSD" || sed -i '/Order allow,deny/a\  Allow @LOCAL' "$CUPSD"
# Share the printer and allow remote administration
cupsctl --share-printers --remote-admin
# CUPS admin user
if [ -n "$REAL_USER" ]; then
    usermod -aG lpadmin "$REAL_USER"
fi
systemctl restart cups
ok "CUPS listens on :631 and is open to the LAN"

# ─── 4. Create the printer queue ────────────────────────────────────────────
step "4/6 Looking for printer and driver"
if lsusb | grep -qi '03f0:2b17'; then
    ok "HP LaserJet 1020 detected on USB"
else
    warn "Printer not found on USB. Check the cable and power, then re-run this script."
fi

URI="$(lpinfo -v | awk 'BEGIN{IGNORECASE=1} /^direct usb.*1020/ {print $2; exit}')"
MODEL="$(lpinfo -m 2>/dev/null | grep -i '1020' | grep -i 'zjs' | head -1 | awk '{print $1}')"
[ -z "$MODEL" ] && MODEL="$(lpinfo -m 2>/dev/null | grep -i 'laserjet.*1020' | head -1 | awk '{print $1}')"

if [ -n "$URI" ] && [ -n "$MODEL" ]; then
    lpadmin -x "$PRINTER_NAME" 2>/dev/null || true
    lpadmin -p "$PRINTER_NAME" -E -v "$URI" -m "$MODEL" \
        -L "HP LaserJet 1020 (Raspberry Pi)" \
        -o printer-is-shared=true
    lpadmin -d "$PRINTER_NAME"
    ok "Printer $PRINTER_NAME added: $URI (driver: $MODEL)"
elif [ -z "$URI" ]; then
    warn "CUPS sees no USB printer (lpinfo -v). Power it on and re-run this script."
else
    warn "No LaserJet 1020 PPD found in lpinfo -m — check printer-driver-foo2zjs install."
fi

# ─── 5. Upload firmware to the printer ──────────────────────────────────────
step "5/6 Uploading firmware to the printer"
if lsusb | grep -qi '03f0:2b17'; then
    # Stock loader from the package — finds the printer via the CUPS usb backend
    SUBSYSTEM=usb /lib/udev/hplj1020 || true
    echo "Waiting for firmware upload (the printer LED blinks ~5 s)..."
    sleep 10
    for dev in /dev/usb/lp*; do
        [ -e "$dev" ] || continue
        if usb_printerid "$dev" 2>/dev/null | grep -q 'FWVER'; then
            ok "Firmware loaded — printer ready ($dev, FWVER present)"
        else
            warn "No FWVER on $dev — firmware may not have loaded"
        fi
    done
    # Fallback check without usblp: FWVER in the CUPS usb backend output
    if /usr/lib/cups/backend/usb 2>/dev/null | grep -q 'FWVER'; then
        ok "FWVER confirmed via CUPS backend"
    fi
else
    warn "Printer not connected — firmware will upload automatically when it powers on"
fi

# ─── 6. Summary ─────────────────────────────────────────────────────────────
step "6/6 Status"
lpstat -t || true
IP="$(hostname -I | awk '{print $1}')"
HOST="$(hostname)"
cat <<EOF

Done. Next steps:

  * If the printer was off — power it on: udev uploads the firmware
    automatically (orange LED blinks ~5 s).
  * Test page:              lp -d $PRINTER_NAME /usr/share/cups/data/testprint
  * CUPS web interface:     http://$IP:631  (or http://$HOST.local:631)
  * Client printer URL:     http://$HOST.local:631/printers/$PRINTER_NAME
    (per-OS instructions — docs/03-clients.md)
  * Troubleshooting:        sudo bash diagnostics.sh

EOF
