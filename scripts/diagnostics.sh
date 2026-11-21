#!/bin/bash
#
# diagnostics.sh — collect print-server diagnostics.
# Usage:  sudo bash diagnostics.sh  (without sudo shows less)

sep() { printf '\n========== %s ==========\n' "$*"; }

sep "System"
uname -a
cat /etc/os-release 2>/dev/null | grep -E 'PRETTY|VERSION='
uptime
free -h | head -2

sep "Network"
hostname -I 2>/dev/null
ip -brief addr 2>/dev/null || ip addr

sep "USB devices"
lsusb 2>/dev/null || echo "lsusb not found"
echo
ls -l /dev/usb/ 2>/dev/null || echo "no /dev/usb (usblp didn't create a device — that's OK)"

sep "Printer id / firmware status"
for dev in /dev/usb/lp*; do
    [ -e "$dev" ] || continue
    echo "--- $dev:"
    usb_printerid "$dev" 2>&1 || true
    echo "(a FWVER line = firmware is loaded)"
done
echo "--- via CUPS usb backend:"
/usr/lib/cups/backend/usb 2>/dev/null | grep -i laserjet || true

sep "Firmware files"
ls -l /lib/firmware/hp/ /var/lib/foo2zjs/firmware/ /usr/share/foo2zjs/firmware/ 2>/dev/null

sep "CUPS: printers"
lpstat -t 2>&1 || true
echo
lpinfo -v 2>&1 | grep -i usb || true

sep "CUPS: listening ports"
ss -ltnp 2>/dev/null | grep -E '631|State' || netstat -ltn 2>/dev/null | grep 631

sep "CUPS: access settings"
grep -E '^(Listen|Port|Browsing|BrowseLocalProtocols|DefaultShared)' /etc/cups/cupsd.conf 2>/dev/null
grep -n 'Allow' /etc/cups/cupsd.conf 2>/dev/null | head -10

sep "Services"
for s in cups avahi-daemon; do
    systemctl is-active --quiet "$s" && echo "$s: active" || echo "$s: INACTIVE"
done

sep "CUPS error log (last 30 lines)"
tail -n 30 /var/log/cups/error_log 2>/dev/null || journalctl -u cups -n 30 --no-pager 2>/dev/null

sep "Firmware loader log"
journalctl --no-pager 2>/dev/null | grep -i 'hplj\|foo2zjs' | tail -20 || echo "nothing"
