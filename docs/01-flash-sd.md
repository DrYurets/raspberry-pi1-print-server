# Шаг 1. Запись Raspberry Pi OS на microSD-карту

Raspberry Pi 1 Model B Rev 2 поддерживается официальной 32-битной
Raspberry Pi OS. Ставим вариант **Lite** — без графического интерфейса,
экономим все 512 МБ ОЗУ под печать.

## 1.1. Что понадобится

- microSD-карта (уже есть) и кардридер
- Компьютер с интернетом

## 1.2. Запись образа

1. Скачайте и установите **Raspberry Pi Imager**:
   https://www.raspberrypi.com/software/

2. Вставьте microSD в компьютер, запустите Imager.

3. Заполните три пункта:
   - **Устройство (Device):** можно оставить "No filtering" — образ Lite
     подходит всем моделям
   - **ОС (Choose OS):** `Raspberry Pi OS (other)` →
     `Raspberry Pi OS Lite (32-bit)`
   - **Карта (Storage):** ваша microSD

4. Нажмите **Next** → Imager предложит настроить систему
   ("Edit settings" / шестерёнка). Заполните:

   | Параметр | Значение |
   |---|---|
   | Hostname | `printserver` |
   | Username | например `pi` (или ваше имя) |
   | Password | придумайте надёжный |
   | Configure wireless LAN | **пропустите** — у нас Ethernet |
   | Locale | часовой пояс и раскладка |

   На вкладке **Services** включите **SSH** → "Use password authentication".

5. Запишите образ, дождитесь верификации.

## 1.3. Первый запуск Pi

Подключайте в таком порядке:

1. Ethernet-кабель в роутер и Pi
2. USB-кабель принтера в Pi (принтер можно пока не включать)
3. **Последним** — блок питания micro-USB

Первый запуск занимает 1–3 минуты (расширение ФС, генерация ключей SSH).
На Pi 1 — терпеливо.

## 1.4. Подключение по SSH

С вашего компьютера:

```bash
ssh pi@printserver.local     # подставьте своё имя пользователя
```

Если `printserver.local` не резолвится — найдите IP в веб-интерфейсе
роутера (список DHCP-клиентов) или просканируйте сеть:

```bash
# Linux: sudo apt install nmap; Windows: скачать nmap или посмотреть в роутере
nmap -sn 192.168.1.0/24 | grep -B2 -i raspberry
```

Дальше → [02-setup-print-server.md](02-setup-print-server.md)
