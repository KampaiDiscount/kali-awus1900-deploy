# Changelog

All notable changes to this project are documented here.

## [1.1.3] - 2026-08-04

### Removed

- GitHub publishing, GitHub CLI installation, and release-packaging helpers. The repository now focuses on the public AWUS1900 driver installer and its validation tooling.

### Changed

- Added a direct standalone-installer download path.
- Corrected the public clone URL and made the project and maintainer easier to find through natural AWUS1900 driver searches.

## [1.1.0] - 2026-07-29

### Added

- GitHub-ready repository layout.
- GitHub Actions static validation.
- Issue and pull-request templates.
- VirtualBox, troubleshooting, compatibility, and driver-selection documentation.
- Public `--version` command.
- Explicit `auto` action alias.

### Changed

- Corrected the diagnostic follow-up command so it invokes the current script path.
- Default action is now named `auto`; behavior remains DKMS attempt with clean native fallback.
- Help and version output no longer require root.

## [1.0.0] - 2026-07-29

### Added

- AWUS1900 USB detection and SuperSpeed reporting.
- Kali DKMS installation path.
- Native `rtw88_8814au` fallback.
- Safe module blacklisting.
- USB autosuspend override.
- Status and mode helpers.
- Reversible monitor-mode smoke test.
- Diagnostic and DKMS failure logging.
