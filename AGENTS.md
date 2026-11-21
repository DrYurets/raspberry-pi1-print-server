# AGENTS.md — Raspberry Pi 1 принт-сервер для HP LaserJet 1020

Состояние проекта: **работает**. Тестовые страницы печатаются и с сервера,
и с клиентского ноутбука по сети.

## Железо и топология

- **Сервер:** Raspberry Pi 1 Model B Rev 2, 512 МБ, Ethernet к роутеру.
- **Принтер:** HP LaserJet 1020, USB `03f0:2b17`, serial `FN14TA7` — подключён к Pi.
- **Питание:** 3А micro-USB БП. ВАЖНО: комплектный слабый БП вызывал
  просадки → I/O error → rootfs уходила в read-only во время `apt`.
  Если снова словите I/O errors — подозревать питание И карту
  (карта дешёвая noname 16 ГБ; read-тест прошла, но запасная карта не помешает).
- **SD:** 16 ГБ, образ `2026-10-06-raspios-trixie-armhf-lite` (Raspberry Pi OS Lite 32-bit, Trixie).

## Сеть

- hostname: `printserver` (mDNS: `printserver.local`)
- IP: `192.168.1.20` (DHCP). MAC: `b8:27:eb:c7:b2:79` — рекомендуется
  резервирование в роутере.
- Доступ: `ssh pi@printserver.local` (ключ `~/.ssh/id_ed25519` с ноутбука;
  пароль есть на случай проблем, sudo — NOPASSWD).
- timezone: Europe/Minsk.

## Ключевая архитектура

HP 1020 — host-based принтер: прошивку нужно заливать при **каждом**
включении. Поэтому:

- **Драйвер `foo2zjs`** (`printer-driver-foo2zjs` + `-common`). hplip НЕ подходит.
- Прошивка: `getweb 1020` → `/lib/firmware/hp/sihp1020.dl` (+ копии в
  `/var/lib/foo2zjs/firmware/`, `/usr/share/foo2zjs/firmware/`).
- Автозагрузка: udev-правило `85-hplj10xx.rules` → `/lib/udev/hplj1020`
  (грузит через CUPS usb-backend). Проверка: `FWVER` в выводе
  `sudo /usr/lib/cups/backend/usb` — есть → прошивка в принтере.
  (`/dev/usb/lp*` может не существовать — usblp не всегда поднят.)
- **CUPS 2.4.10**, очередь `HP1020` → `usb://HP/LaserJet%201020?serial=FN14TA7`,
  PPD `foo2zjs:0/ppd/foo2zjs/HP-LaserJet_1020.ppd`. Шаринг: `Port 631` +
  `Allow @LOCAL` во всех Location + `printer-is-shared`. WebInterface=yes,
  remote-admin включён. Web UI: `http://printserver.local:631`.
- **avahi-daemon** — mDNS-анонс (клиенты находят принтер сами).

## Клиенты

- Ноутбук (Ubuntu 24.04): очередь `HP1020` → `ipp://printserver.local:631/printers/HP1020`,
  `-m everywhere` (IPP Everywhere), принтер по умолчанию. Клиент шлёт PDF,
  сервер растрирует gs→foo2zjs→ZjStream.
- Windows: добавить по URL `http://printserver.local:631/printers/HP1020`,
  драйвер **Microsoft PS Class Driver** (или MS Publisher Imagesetter) —
  CUPS на Pi конвертирует PS сам. Родной драйвер HP 1020 через IPP не работает.
- Android: штатная служба печати (mDNS) или Mopria.

## Грабли, уже наступленные

1. **Слабый БП = труп ФС.** Просадка → I/O errors → ro-remount →
   полуразваленный apt. Лечится перезаписью карты + нормальный БП.
2. **Trixie требует `userconf.txt`** в bootfs (`pi:sha512crypt`) — иначе
   `userconfig.service` вешает загрузку интерактивным мастером на tty8.
   SSH включается пустым файлом `ssh` в bootfs (через `sshswitch.service`).
3. **Принтер должен быть включён** при создании очереди — `lpinfo -v`
   не покажет URI с выключенным принтером. Скрипт идемпотентен — перезапустить.
4. Смена карты = новые host keys → чистить `known_hosts`.

## Проверка и диагностика

- Тест-страница на сервере: `lp -d HP1020 /usr/share/cups/data/testprint`
  (рендер на Pi 1 — до ~30-60 с на страницу, терпеть).
- Логи: `/var/log/cups/error_log`, `journalctl | grep -i hplj` (загрузчик прошивки).
- Диагностика: `sudo bash ~/printserver/scripts/diagnostics.sh`.

## Файлы проекта

- `scripts/setup-print-server.sh` — вся настройка (идемпотентный)
- `scripts/load-firmware.sh` — ручная заливка прошивки
- `scripts/diagnostics.sh` — сбор диагностики
- `docs/01..04` — пошаговые инструкции (запись SD, настройка, клиенты, траблшутинг)
- На Pi: копия в `~/printserver/` (вкладывается в bootfs при записи карты)
- `images/` — скачанный образ ОС (570 МБ .img.xz, в git не идёт)
