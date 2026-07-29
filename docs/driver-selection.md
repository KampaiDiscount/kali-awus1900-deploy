# Driver selection

## Automatic path

The default command:

```bash
sudo ./awus1900-deploy.sh
```

attempts the standalone Kali DKMS package first. It activates that path only when a loadable `8814au` module exists for the running kernel.

When the module is skipped or fails:

1. DKMS evidence is captured.
2. The package is purged.
3. `dpkg` consistency is repaired.
4. the project-specific blacklist is removed;
5. the in-kernel `rtw88_8814au` path is configured and validated.

## Native path

Use:

```bash
sudo ./awus1900-deploy.sh native
```

The native path is appropriate when the running kernel already provides `rtw88_8814au`, its firmware is installed, and the required functionality works.

## DKMS path

Use:

```bash
sudo ./awus1900-deploy.sh dkms
```

This explicitly requests the standalone package but still retains the clean fallback. The script does not force a DKMS module past its declared kernel exclusion.

## Why not blacklist first?

Blacklisting the native driver before confirming a successful DKMS build can leave the adapter with no usable driver after a kernel transition. This project writes the native-driver blacklist only after the standalone module has been built and found by `modinfo`.
