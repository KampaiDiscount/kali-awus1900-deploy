# VirtualBox USB setup

## Recommended VM configuration

```text
Controller: USB 3.0 (xHCI)
Filter name: ALFA AWUS1900
Vendor ID: 0BDA
Product ID: 8813
Remote: No
```

Keep the remaining filter fields empty unless there is a specific reason to constrain them.

## Validate ownership inside Kali

```bash
lsusb -d 0bda:8813
lsusb -t
```

A healthy SuperSpeed attachment normally reports `5000M` for the adapter path.

## Adapter disappears from `lsusb`

When the adapter disappears from `lsusb`, the problem is below the wireless-driver layer. The guest no longer owns the USB device.

Check:

1. VirtualBox **Devices -> USB -> Realtek 802.11ac NIC**.
2. The USB filter uses only the stable vendor/product identifiers.
3. The adapter is connected directly or through a sufficiently powered USB 3.x hub.
4. Windows is not reclaiming the device.
5. The Extension Pack version, where applicable, matches the VirtualBox host version.

Watch events:

```bash
sudo dmesg -wT | grep --line-buffered -Ei   'usb|xhci|8814|rtw88|reset|disconnect|error|fail'
```

In another terminal:

```bash
watch -n 0.5 'lsusb -d 0bda:8813; echo; lsusb -t'
```
