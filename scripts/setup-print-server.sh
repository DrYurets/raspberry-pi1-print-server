#!/bin/bash
#
# setup-print-server.sh — настройка Raspberry Pi (OS Lite) как принт-сервера
# для HP LaserJet 1020.
#
# Что делает скрипт:
#   1. Устанавливает CUPS, драйвер foo2zjs, avahi (mDNS)
#   2. Скачивает прошивку sihp1020.dl (обязательна: без неё 1020 не печатает,
#      она загружается в принтер при каждом его включении через udev)
#   3. Открывает CUPS для локальной сети (IPP на порту 631)
#   4. Добавляет принтер в CUPS и делает его общим
#   5. Загружает прошивку в принтер, если он уже подключен
#
# Запуск на Raspberry Pi:
#   sudo bash setup-print-server.sh
#
# Скрипт идемпотентен — можно запускать повторно.

set -euo pipefail

PRINTER_NAME="HP1020"
FW_NAME="sihp1020.dl"
FW_DIRS="/lib/firmware/hp /var/lib/foo2zjs/firmware /usr/share/foo2zjs/firmware"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Запустите от root: sudo bash $0"
REAL_USER="${SUDO_USER:-}"

# ─── 1. Пакеты ──────────────────────────────────────────────────────────────
step "1/6 Установка пакетов (может занять время на Pi 1)"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    cups cups-filters ghostscript \
    printer-driver-foo2zjs printer-driver-foo2zjs-common foomatic-db-engine \
    avahi-daemon wget usbutils
systemctl enable --now cups avahi-daemon
ok "Пакеты установлены"

# ─── 2. Прошивка принтера ───────────────────────────────────────────────────
step "2/6 Прошивка $FW_NAME"
if [ -f "/lib/firmware/hp/$FW_NAME" ]; then
    ok "Уже есть: /lib/firmware/hp/$FW_NAME"
else
    TMPD="$(mktemp -d)"
    ( cd "$TMPD" && mkdir -p /lib/firmware/hp && getweb 1020 )
    rm -rf "$TMPD"
fi
[ -f "/lib/firmware/hp/$FW_NAME" ] || die "Не удалось получить $FW_NAME (проверьте интернет на Pi)"
# Копии в альтернативные каталоги — на случай другой сборки загрузчика
for d in $FW_DIRS; do
    mkdir -p "$d"
    [ -f "$d/$FW_NAME" ] || cp "/lib/firmware/hp/$FW_NAME" "$d/" 2>/dev/null || true
done
ls -l "/lib/firmware/hp/$FW_NAME"
udevadm control --reload-rules

# ─── 3. CUPS: доступ из локальной сети ──────────────────────────────────────
step "3/6 Настройка CUPS для LAN"
CUPSD=/etc/cups/cupsd.conf
[ -f "$CUPSD.bak" ] || cp "$CUPSD" "$CUPSD.bak"
# Слушать все интерфейсы на порту 631
if grep -qE '^Listen[[:space:]]+localhost:631' "$CUPSD"; then
    sed -i 's/^Listen[[:space:]]\+localhost:631/Port 631/' "$CUPSD"
elif ! grep -qE '^(Port|Listen)[[:space:]]+.*:631' "$CUPSD"; then
    echo 'Port 631' >> "$CUPSD"
fi
# Разрешить доступ с локальных интерфейсов во все Location-блоки
grep -q 'Allow @LOCAL' "$CUPSD" || sed -i '/Order allow,deny/a\  Allow @LOCAL' "$CUPSD"
# Публиковать принтер и разрешить удалённое администрирование
cupsctl --share-printers --remote-admin
# Пользователь-администратор CUPS
[ -n "$REAL_USER" ] && usermod -aG lpadmin "$REAL_USER" || true
systemctl restart cups
ok "CUPS слушает :631 и открыт для локальной сети"

# ─── 4. Добавление принтера ─────────────────────────────────────────────────
step "4/6 Поиск принтера и драйвера"
if lsusb | grep -qi '03f0:2b17'; then
    ok "HP LaserJet 1020 виден на USB"
else
    warn "Принтер не обнаружен на USB. Проверьте кабель и питание, затем перезапустите скрипт."
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
    ok "Принтер $PRINTER_NAME добавлен: $URI (драйвер: $MODEL)"
elif [ -z "$URI" ]; then
    warn "CUPS не видит принтер по USB (lpinfo -v). Подключите принтер, включите его и запустите скрипт повторно."
else
    warn "Не найден PPD для LaserJet 1020 в lpinfo -m — проверьте установку printer-driver-foo2zjs."
fi

# ─── 5. Загрузка прошивки в принтер ─────────────────────────────────────────
step "5/6 Загрузка прошивки в принтер"
if lsusb | grep -qi '03f0:2b17'; then
    # Штатный загрузчик пакета: сам найдёт принтер через CUPS usb-backend
    SUBSYSTEM=usb /lib/udev/hplj1020 || true
    echo "Ожидаем загрузку прошивки (индикатор на принтере мигнёт ~5 сек)..."
    sleep 10
    for dev in /dev/usb/lp*; do
        [ -e "$dev" ] || continue
        if usb_printerid "$dev" 2>/dev/null | grep -q 'FWVER'; then
            ok "Прошивка загружена — принтер готов ($dev, FWVER есть)"
        else
            warn "FWVER не виден на $dev — прошивка могла не загрузиться"
        fi
    done
else
    warn "Принтер не подключен — прошивка загрузится автоматически при его включении"
fi

# ─── 6. Итог ────────────────────────────────────────────────────────────────
step "6/6 Статус"
lpstat -t || true
IP="$(hostname -I | awk '{print $1}')"
HOST="$(hostname)"
cat <<EOF

Готово. Дальше:

  * Если принтер был выключен — включите его: udev сам загрузит прошивку
    (индикатор мигнёт оранжевым ~5 сек).
  * Тестовая страница:      lp -d $PRINTER_NAME /usr/share/cups/data/testprint
  * Веб-интерфейс CUPS:     http://$IP:631  (или http://$HOST.local:631)
  * Подключение клиентов:   http://$HOST.local:631/printers/$PRINTER_NAME
    (инструкции — docs/03-clients.md)
  * Диагностика проблем:    sudo bash diagnostics.sh

EOF
