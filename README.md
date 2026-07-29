# Kali AWUS1900 Deploy

Resilient deployment and recovery tooling for the **ALFA AWUS1900**, **Realtek RTL8814AU**, and USB ID **`0bda:8813`** on Kali Linux.

The project validates USB passthrough, attempts Kali's standalone DKMS package, detects an unsupported or skipped DKMS build, rolls back cleanly, and falls back to the in-kernel `rtw88_8814au` driver. It also installs diagnostics and reversible monitor-mode helpers.

> This project is community maintained and is not affiliated with ALFA Network, Realtek, Kali Linux, Offensive Security, Oracle, or VirtualBox.

## Why this exists

RTL8814AU setup advice is often reduced to “clone a driver and hope.” That approach is fragile on rolling kernels. This installer treats deployment as a controlled state transition:

```text
USB 0bda:8813 visible
        |
SuperSpeed path checked
        |
running-kernel headers checked
        |
Kali DKMS package attempted
        |
        +-- module built --> activate 8814au
        |
        +-- rejected/skipped --> purge failed state
                                  |
                                  +--> activate rtw88_8814au
                                             |
                                      validate interface
                                             |
                                      smoke-test monitor mode
```

## Features

- Detects the AWUS1900 by exact USB ID.
- Reports the negotiated USB speed and warns about non-SuperSpeed attachment.
- Installs matching build prerequisites without forcing `apt full-upgrade`.
- Attempts `realtek-rtl8814au-dkms`.
- Detects DKMS `BUILD_EXCLUSIVE` skips and other failed builds.
- Captures DKMS failure logs before cleanup.
- Purges an unusable DKMS installation instead of leaving broken package state.
- Falls back to the native `rtw88_8814au` module.
- Blacklists the native RTL8814AU-specific modules only after DKMS succeeds.
- Adds an AWUS1900-specific USB autosuspend override.
- Installs status and reversible mode-switching helpers.
- Provides a non-transmitting monitor-mode smoke test.
- Logs deployment activity under `/var/log/awus1900/`.
- Provides a clean removal path.

## Tested compatibility

| Platform | Kernel | USB path | Result |
|---|---|---:|---|
| Kali GNU/Linux Rolling in VirtualBox | `7.0.12+kali-amd64` | 5000 Mbit/s | DKMS package skipped by `BUILD_EXCLUSIVE`; automatic native fallback succeeded with `rtw88_8814au`, `wlan0`, and advertised monitor mode |

See [Compatibility notes](docs/compatibility.md).

## VirtualBox prerequisites

Power off the VM and configure:

```text
USB controller: USB 3.0 (xHCI)
USB filter name: ALFA AWUS1900
Vendor ID: 0BDA
Product ID: 8813
Remote: No
```

Leave revision, manufacturer, product, serial number, and port blank unless a specific environment requires them. Connect the adapter directly to a powered USB 3.x port where possible.

Detailed instructions: [VirtualBox USB setup](docs/virtualbox-usb.md).

## Quick start

Clone the repository and run the deployment:

```bash
git clone https://github.com/KampaiDiscount/kali-awus1900-deploy.git
cd kali-awus1900-deploy
sudo ./awus1900-deploy.sh
```

The default `auto` path attempts Kali's DKMS package and safely falls back to the native driver when the module is unsupported or skipped.

## Commands

```bash
# Automatic deployment: DKMS attempt with native fallback
sudo ./awus1900-deploy.sh

# Explicitly request the automatic path
sudo ./awus1900-deploy.sh auto

# Explicitly attempt Kali's standalone DKMS package
sudo ./awus1900-deploy.sh dkms

# Use only the in-kernel driver
sudo ./awus1900-deploy.sh native

# Collect hardware, package, module, interface, and kernel diagnostics
sudo ./awus1900-deploy.sh diagnose

# Reversible, non-transmitting monitor-mode test
sudo ./awus1900-deploy.sh smoke-test

# Test monitor-mode switching and select channel 36
sudo ./awus1900-deploy.sh smoke-test 36

# Remove the standalone deployment and return to the native driver
sudo ./awus1900-deploy.sh remove
```

## Installed helpers

After a successful deployment:

```bash
awus1900-status
sudo awus1900-mode monitor
sudo awus1900-mode monitor 36
sudo awus1900-mode managed
```

`awus1900-mode monitor` changes the target interface type. It does not transmit frames by itself.

## Verification

Check that the adapter remains visible:

```bash
lsusb -d 0bda:8813
lsusb -t
```

Check the bound interface and driver:

```bash
awus1900-status
```

A successful native path should normally report:

```text
Interface: wlan0
driver: rtw88_8814au
```

A successful standalone DKMS path should normally report:

```text
driver: 8814au
```

## Safety and scope

The deployment and smoke test do not automatically perform packet injection, deauthentication, credential capture, or network access. Wireless transmission tests must be limited to hardware and networks you own or are explicitly authorized to assess.

## Troubleshooting

Start with:

```bash
sudo ./awus1900-deploy.sh diagnose
```

Then review:

```text
/var/log/awus1900/
```

Common failure paths are documented in [Troubleshooting](docs/troubleshooting.md).

## Development

Run local static checks:

```bash
./tests/static.sh
```

Create a release archive:

```bash
./scripts/package-release.sh
```

The repository enforces LF line endings for shell scripts through `.gitattributes` and `.editorconfig`.

## Contributing

Bug reports and pull requests are welcome. Include the kernel, Kali branch, USB ID, virtualization platform, driver selected, and sanitized diagnostic output.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
