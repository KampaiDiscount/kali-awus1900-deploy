# Contributing

## Before opening an issue

Run:

```bash
sudo ./awus1900-deploy.sh diagnose
```

Sanitize the output before posting it. Remove usernames, hostnames, public IP addresses, unrelated USB serial numbers, network names, and MAC addresses when they are not necessary to reproduce the issue.

Include:

- Kali release or branch.
- `uname -r`.
- Virtualization platform or bare-metal status.
- `lsusb -d 0bda:8813`.
- Relevant section of `lsusb -t`.
- Driver selected: `8814au` or `rtw88_8814au`.
- Exact action used.
- The failure stage and error output.

## Pull requests

1. Keep shell scripts compatible with Bash.
2. Preserve LF line endings.
3. Run `./tests/static.sh`.
4. Keep changes narrow and explain the failure mode they address.
5. Do not add forced kernel upgrades, insecure repository keys, unsigned binary downloads, or opaque third-party installers.
6. Do not add automatic packet injection or disruptive wireless operations to the default workflow.

## Commit style

Use short imperative subjects, for example:

```text
Handle DKMS build exclusion cleanly
Improve VirtualBox USB diagnostics
Document native driver fallback
```
