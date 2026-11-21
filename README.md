# Raspberry Pi 1 → принт-сервер для HP LaserJet 1020

Цель: подключить USB-принтер **HP LaserJet 1020** к домашней LAN через
**Raspberry Pi 1 Model B Rev 2 (512 МБ)**, чтобы печатать с любых
устройств в сети.

## Архитектура

```
Windows / Android / Linux
         │  IPP (TCP :631), mDNS-обнаружение
         ▼
   Raspberry Pi 1 B ── Ethernet ──► роутер (LAN)
   ├── CUPS        — принт-сервер, очередь, конвертация в растр
   ├── foo2zjs     — драйвер HP 1020 (растр → ZjStream)
   ├── udev-правило — автозагрузка прошивки при включении принтера
   └── avahi       — анонс принтера в сеть (Bonjour/mDNS)
         │ USB
         ▼
   HP LaserJet 1020  ◄── прошивка sihp1020.dl при каждом включении
```

**Важно про HP 1020:** принтер не хранит прошивку — Pi загружает её
автоматически каждый раз, когда принтер включается или подключается
по USB. Один раз прошивку нужно скачать (делает setup-скрипт).

## Шаги

| # | Что | Инструкция |
|---|-----|-----------|
| 1 | Записать Raspberry Pi OS Lite на SD-карту | [docs/01-flash-sd.md](docs/01-flash-sd.md) |
| 2 | Настроить Pi: CUPS + foo2zjs + прошивка | [docs/02-setup-print-server.md](docs/02-setup-print-server.md) |
| 3 | Подключить клиентов (Windows/Android/Linux) | [docs/03-clients.md](docs/03-clients.md) |
| — | Если что-то не работает | [docs/04-troubleshooting.md](docs/04-troubleshooting.md) |

## Файлы

```
scripts/setup-print-server.sh   # автонастройка: пакеты, CUPS, прошивка, принтер
scripts/load-firmware.sh        # ручная загрузка прошивки (если udev не сработал)
scripts/diagnostics.sh          # сбор диагностики при проблемах
docs/                           # пошаговые инструкции
```

## Быстрый старт (после первой загрузки Pi)

```bash
# с компьютера:
scp -r scripts pi@printserver.local:~/

# на Pi:
cd ~/scripts && sudo bash setup-print-server.sh
# включить принтер → прошивка загрузится сама
lp -d HP1020 /usr/share/cups/data/testprint
```

Принтер для клиентов: `http://printserver.local:631/printers/HP1020`

## Примечания

- Pi 1 B подключён по Ethernet (Wi-Fi на борту нет; понадобился бы
  USB-адаптер — не наш случай).
- hplip **не** подходит для LJ1020 — только foo2zjs.
- 512 МБ достаточно; опционально `gpu_mem=16` освобождает ~48 МБ.
- Рекомендуется зарезервировать IP за Pi в роутере.
