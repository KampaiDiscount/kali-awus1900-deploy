# Troubleshooting

## First response

```bash
sudo ./awus1900-deploy.sh diagnose
```

Review the newest files under:

```text
/var/log/awus1900/
```

## `0bda:8813` is absent

```bash
lsusb -d 0bda:8813
```

No output means the guest does not currently own the device. Fix USB passthrough before changing drivers.

## Adapter is on a slow USB path

```bash
lsusb -t
```

A `480M` path indicates high-speed USB 2 operation. The adapter may function, but bandwidth and stability testing should be repeated after fixing SuperSpeed passthrough.

## DKMS says `BUILD_EXCLUSIVE`

This is an intentional package exclusion, not necessarily a compiler error. The default installer should purge the unusable standalone package and activate `rtw88_8814au`.

## USB is visible but no interface appears

```bash
sudo modprobe rtw88_8814au
sudo udevadm settle
ip -br link
iw dev
```

Then inspect:

```bash
sudo dmesg --color=never |
grep -Ei '8814|rtw88|firmware|usb.*(reset|disconnect|error|fail)' |
tail -n 160
```

## Driver conflict

```bash
lsmod | grep -E '(^8814au|rtw88_8814|rtw88_usb|rtw88_core)'
```

A successful deployment should not have both the standalone `8814au` module and the native RTL8814AU-specific module controlling the same device.

## Return to native

```bash
sudo ./awus1900-deploy.sh remove
sudo ./awus1900-deploy.sh native
```

## Monitor-mode smoke test

```bash
sudo ./awus1900-deploy.sh smoke-test 36
```

The test restores the original interface type when it exits. It does not transmit frames or prove packet injection.
