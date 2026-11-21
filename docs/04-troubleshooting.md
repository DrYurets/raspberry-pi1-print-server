# Диагностика и решение проблем

Начните со сбора информации на Pi:

```bash
sudo bash ~/scripts/diagnostics.sh
```

## Симптом: задание уходит, принтер молчит или мигает и ничего не печатает

**99% случаев — в принтере нет прошивки.** HP 1020 без неё — кирпич.

Проверка:

```bash
usb_printerid /dev/usb/lp0
```

- Есть строка `FWVER=...` → прошивка на месте, проблема в другом.
- Нет `FWVER` → загрузите вручную: `sudo bash ~/scripts/load-firmware.sh`

Если ручная загрузка помогла, но автоматически не грузится при включении —
сработало ли udev-правило? Проверьте имя продукта:

```bash
lsusb -d 03f0:2b17 -v 2>/dev/null | grep iProduct
```

Правило `/lib/udev/rules.d/85-hplj10xx.rules` ждёт строку
`HP LaserJet 1020`. Если у принтера другая строка (бывает `hp LaserJet 1020`),
добавьте правило по ID устройства — файл `/etc/udev/rules.d/99-hp1020.rules`:

```
ACTION=="add", SUBSYSTEMS=="usb", ATTRS{idVendor}=="03f0", ATTRS{idProduct}=="2b17", RUN+="hplj1020"
```

Затем `sudo udevadm control --reload`.

## Симптом: принтер не виден даже в lsusb

- Другой USB-кабель (у 1020 кабели привередливы), другой порт Pi.
- Питание: у Pi 1 слабый USB — принтер питается от сети, так что должно
  хватать, но просадки 5V влияют на всё. Блок питания ≥ 1А.
- `dmesg | tail -20` — есть ли строки про new USB device.

## Симптом: клиенты не видят принтер / не открывается :631

```bash
ss -ltn | grep 631        # на Pi: должен слушать 0.0.0.0:631
lpstat -v                  # принтер добавлен?
lpstat -o                  # очередь
```

Если слушает только `127.0.0.1:631` — в `/etc/cups/cupsd.conf`
должно быть `Port 631` (а не `Listen localhost:631`), после правки:
`sudo systemctl restart cups`.

Проверка с клиента: откройте `http://<IP-Pi>:631` в браузере —
должна открыться страница CUPS.

## Симптом: Windows подключилась, но печатает мусор/коды

Драйвер выбран не PostScript — CUPS получил сырые данные, которые не умеет
конвертировать. Переустановите принтер с драйвером
**Microsoft PS Class Driver** или **MS Publisher Imagesetter**.

## Логи

```bash
sudo tail -50 /var/log/cups/error_log     # ошибки CUPS
sudo journalctl -u cups -n 50             # сервис
sudo journalctl | grep -i hplj | tail     # загрузчик прошивки
```

Уровень логирования: `sudo cupsctl --debug-logging`, воспроизвести
проблему, потом выключить: `sudo cupsctl --no-debug-logging`.

## Симптом: apt install вешается / ошибки памяти

На 512 МБ бывает тесно при больших операциях. Добавьте `gpu_mem=16`
в `/boot/firmware/config.txt`, перезагрузитесь. Можно временно увеличить
swap: `sudo dphys-swapfile swapoff`, в `/etc/dphys-swapfile` поставить
`CONF_SWAPSIZE=512`, `sudo dphys-swapfile setup && sudo dphys-swapfile swapon`.
