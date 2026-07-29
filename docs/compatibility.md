# Compatibility notes

## Confirmed test

| Item | Value |
|---|---|
| Distribution | Kali GNU/Linux Rolling |
| Kernel | `7.0.12+kali-amd64` |
| Adapter | ALFA AWUS1900 / RTL8814AU |
| USB ID | `0bda:8813` |
| Hypervisor | VirtualBox |
| USB negotiation | 5000 Mbit/s |
| Kali DKMS package | `realtek-rtl8814au-dkms` `5.8.5.1~git20250903.8d82854-0kali1` |
| DKMS outcome | Skipped due to a non-matching `BUILD_EXCLUSIVE` directive |
| Fallback | Native `rtw88_8814au` |
| Interface | `wlan0` |
| Monitor capability | Advertised by the active wireless stack |

## Interpretation

A `BUILD_EXCLUSIVE` skip is not the same as a compiler failure. It means the DKMS package declared that it should not build for the current kernel, architecture, or configuration.

The installer treats that as an unavailable DKMS path, captures the available evidence, purges the unused package, restores module-selection state, and activates the native driver.

## Reporting another combination

Submit:

```text
Kali branch:
Kernel:
Adapter USB ID:
Hypervisor/bare metal:
USB speed:
DKMS package version:
Selected driver:
Managed mode:
Monitor mode:
Injection test:
Notes:
```

Do not claim injection support unless it has been tested in an authorized environment.
