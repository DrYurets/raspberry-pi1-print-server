#!/bin/bash
#
# diagnostics.sh — сбор диагностической информации принт-сервера.
# Запуск:  sudo bash diagnostics.sh  (или без sudo — выведет меньше)

sep() { printf '\n========== %s ==========\n' "$*"; }

sep "Система"
uname -a
cat /etc/os-release 2>/dev/null | grep -E 'PRETTY|VERSION='
uptime
free -h | head -2

sep "Сеть"
hostname -I 2>/dev/null
ip -brief addr 2>/dev/null || ip addr

sep "USB-устройства"
lsusb 2>/dev/null || echo "lsusb не найден"
echo
ls -l /dev/usb/ 2>/dev/null || echo "/dev/usb отсутствует (usblp не поднял устройство)"

sep "ID принтера / статус прошивки"
for dev in /dev/usb/lp*; do
    [ -e "$dev" ] || continue
    echo "--- $dev:"
    usb_printerid "$dev" 2>&1 || true
    echo "(наличие строки FWVER = прошивка загружена)"
done

sep "Прошивочные файлы"
ls -l /lib/firmware/hp/ /var/lib/foo2zjs/firmware/ /usr/share/foo2zjs/firmware/ 2>/dev/null

sep "CUPS: принтеры"
lpstat -t 2>&1 || true
echo
lpinfo -v 2>&1 | grep -i usb || true

sep "CUPS: слушаемые порты"
ss -ltnp 2>/dev/null | grep -E '631|State' || netstat -ltn 2>/dev/null | grep 631

sep "CUPS: параметры доступа"
grep -E '^(Listen|Port|Browsing|BrowseLocalProtocols|DefaultShared)' /etc/cups/cupsd.conf 2>/dev/null
grep -n 'Allow' /etc/cups/cupsd.conf 2>/dev/null | head -10

sep "Сервисы"
for s in cups avahi-daemon; do
    systemctl is-active --quiet "$s" && echo "$s: active" || echo "$s: INACTIVE"
done

sep "Лог CUPS (последние 30 строк)"
tail -n 30 /var/log/cups/error_log 2>/dev/null || journalctl -u cups -n 30 --no-pager 2>/dev/null

sep "Лог загрузчика прошивки"
journalctl --no-pager 2>/dev/null | grep -i 'hplj\|foo2zjs' | tail -20 || echo "ничего"
