# Security Policy

## Reporting a vulnerability

Use GitHub private vulnerability reporting when it is enabled for the repository. Otherwise, contact the maintainer privately before opening a public issue.

Do not publish:

- credentials or access tokens;
- private network names or addresses;
- unsanitized packet captures;
- USB serial numbers that uniquely identify unrelated devices;
- private assessment data;
- logs containing client information.

## Supported versions

Security fixes are applied to the latest release.

## Scope

This project manages local packages, kernel modules, udev rules, and wireless interface modes. Security-sensitive changes should preserve these principles:

- download software only through configured Kali repositories;
- do not bypass package signature verification;
- do not disable Secure Boot controls;
- do not install unsigned precompiled kernel modules;
- do not weaken unrelated wireless or network controls;
- do not perform disruptive wireless operations automatically.
