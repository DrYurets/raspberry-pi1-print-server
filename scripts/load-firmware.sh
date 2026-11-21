#!/bin/bash
#
# load-firmware.sh — manual firmware upload to HP LaserJet 1020.
# Needed when the printer was already on and udev didn't upload
# the firmware automatically for some reason.
#
# Usage:  sudo bash load-firmware.sh

set -u

FW=""
for d in /lib/firmware/hp /var/lib/foo2zjs/firmware /usr/share/foo2zjs/firmware; do
    [ -f "$d/sihp1020.dl" ] && { FW="$d/sihp1020.dl"; break; }
done
[ -n "$FW" ] || { echo "Firmware sihp1020.dl not found. Run setup-print-server.sh first"; exit 1; }

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0"; exit 1; }

lsusb | grep -qi '03f0:2b17' || { echo "Printer not visible on USB — check cable and power"; exit 1; }

echo "Uploading $FW via the stock hplj1020 loader..."
SUBSYSTEM=usb /lib/udev/hplj1020
sleep 10

# Check: FWVER in usb_printerid output means firmware is in the printer
LOADED=0
for dev in /dev/usb/lp*; do
    [ -e "$dev" ] || continue
    echo "--- usb_printerid $dev:"
    usb_printerid "$dev" || true
    usb_printerid "$dev" 2>/dev/null | grep -q 'FWVER' && LOADED=1
done

# Fallback check via CUPS backend (works even without /dev/usb/lp*)
if [ "$LOADED" -eq 0 ] && /usr/lib/cups/backend/usb 2>/dev/null | grep -q 'FWVER'; then
    LOADED=1
fi

if [ "$LOADED" -eq 0 ]; then
    echo "hplj1020 didn't work — trying direct write to /dev/usb/lp*..."
    for dev in /dev/usb/lp*; do
        [ -e "$dev" ] || continue
        cat "$FW" > "$dev" && sleep 5
        usb_printerid "$dev" 2>/dev/null | grep -q 'FWVER' && LOADED=1 && break
    done
fi

if [ "$LOADED" -eq 1 ]; then
    echo "OK: firmware loaded, printer ready."
else
    echo "Firmware NOT loaded. See docs/04-troubleshooting.md"
    exit 1
fi
