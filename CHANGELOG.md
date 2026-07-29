# Changelog

All notable changes to this project are documented here.

## [1.1.2] - 2026-07-30

### Fixed

- Initialize the local Git repository before applying repository-local identity settings.
- Configure GitHub CLI as Git's credential helper after authentication.
- Prevent `fatal: not in a git directory` during first-time publishing.

## [1.1.1] - 2026-07-30

### Fixed

- Added an installer for GitHub CLI's official signed APT repository.
- Corrected publishing instructions that incorrectly assumed `gh` was available from Kali's enabled repository.
- Updated the publishing helper to point to the bundled GitHub CLI installer.

## [1.1.0] - 2026-07-29

### Added

- GitHub-ready repository layout.
- GitHub Actions static validation.
- Issue and pull-request templates.
- VirtualBox, troubleshooting, compatibility, and driver-selection documentation.
- One-command GitHub publishing helper.
- Release packaging helper.
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
