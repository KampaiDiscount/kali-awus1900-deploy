#!/usr/bin/env bash
#
# Install Git and the official GitHub CLI package on Kali/Debian.
# Uses GitHub's signed APT repository.
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

if [[ $EUID -eq 0 ]]; then
    SUDO=()
else
    command -v sudo >/dev/null 2>&1 || {
        echo "[ERROR] Run as root or install sudo." >&2
        exit 1
    }
    SUDO=(sudo)
fi

echo "[+] Installing repository prerequisites..."
"${SUDO[@]}" apt-get update
DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y \
    ca-certificates \
    git \
    wget

echo "[+] Installing GitHub CLI repository signing key..."
"${SUDO[@]}" install -d -m 0755 /etc/apt/keyrings
tmp_key="$(mktemp)"
trap 'rm -f "$tmp_key"' EXIT

wget -nv \
    -O "$tmp_key" \
    https://cli.github.com/packages/githubcli-archive-keyring.gpg

"${SUDO[@]}" install \
    -m 0644 \
    "$tmp_key" \
    /etc/apt/keyrings/githubcli-archive-keyring.gpg

echo "[+] Configuring GitHub CLI's official APT repository..."
arch="$(dpkg --print-architecture)"

printf '%s\n' \
    "deb [arch=${arch} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
    "${SUDO[@]}" tee /etc/apt/sources.list.d/github-cli.list >/dev/null

echo "[+] Installing GitHub CLI..."
"${SUDO[@]}" apt-get update
DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y gh

echo
echo "[OK] Installed versions:"
git --version
gh --version | head -n 1

echo
echo "Next:"
echo "  gh auth login"
echo "  gh auth setup-git"
