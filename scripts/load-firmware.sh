#!/bin/bash
#
# load-firmware.sh — ручная загрузка прошивки в HP LaserJet 1020.
# Нужна, если принтер уже был включён и udev по какой-то причине
# не загрузил прошивку автоматически.
#
# Запуск:  sudo bash load-firmware.sh

set -u

FW=""
for d in /lib/firmware/hp /var/lib/foo2zjs/firmware /usr/share/foo2zjs/firmware; do
    [ -f "$d/sihp1020.dl" ] && { FW="$d/sihp1020.dl"; break; }
done
[ -n "$FW" ] || { echo "Прошивка sihp1020.dl не найдена. Сначала запустите setup-print-server.sh"; exit 1; }

[ "$(id -u)" -eq 0 ] || { echo "Запустите от root: sudo bash $0"; exit 1; }

lsusb | grep -qi '03f0:2b17' || { echo "Принтер не виден на USB — проверьте кабель и питание"; exit 1; }

echo "Загружаю $FW через штатный загрузчик hplj1020..."
SUBSYSTEM=usb /lib/udev/hplj1020
sleep 10

# Проверка: FWVER в ответе usb_printerid означает, что прошивка на месте
LOADED=0
for dev in /dev/usb/lp*; do
    [ -e "$dev" ] || continue
    echo "--- usb_printerid $dev:"
    usb_printerid "$dev" || true
    usb_printerid "$dev" 2>/dev/null | grep -q 'FWVER' && LOADED=1
done

if [ "$LOADED" -eq 0 ]; then
    echo "Через hplj1020 не получилось — пробую напрямую в /dev/usb/lp0..."
    for dev in /dev/usb/lp*; do
        [ -e "$dev" ] || continue
        cat "$FW" > "$dev" && sleep 5
        usb_printerid "$dev" 2>/dev/null | grep -q 'FWVER' && LOADED=1 && break
    done
fi

if [ "$LOADED" -eq 1 ]; then
    echo "OK: прошивка загружена, принтер готов к печати."
else
    echo "Прошивка НЕ загружена. См. docs/04-troubleshooting.md"
    exit 1
fi
