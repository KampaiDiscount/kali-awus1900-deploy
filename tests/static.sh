#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

scripts=(
    awus1900-deploy.sh
    publish-to-github.sh
    scripts/package-release.sh
    scripts/install-github-cli.sh
    tests/static.sh
)

for script in "${scripts[@]}"; do
    echo "[+] bash -n ${script}"
    bash -n "$script"

    if grep -q $'\r' "$script"; then
        echo "[ERROR] CRLF detected in ${script}" >&2
        exit 1
    fi
done

if command -v shellcheck >/dev/null 2>&1; then
    echo "[+] shellcheck"
    shellcheck \
        -S warning \
        -e SC1091 \
        awus1900-deploy.sh \
        publish-to-github.sh \
        scripts/package-release.sh \
        scripts/install-github-cli.sh \
        tests/static.sh
else
    echo "[!] shellcheck is not installed; syntax and LF checks completed."
fi

echo "[OK] Static checks passed."
