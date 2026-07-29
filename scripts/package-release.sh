#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(awk -F'"' '/^VERSION=/{print $2; exit}' "$ROOT/awus1900-deploy.sh")"
NAME="kali-awus1900-deploy-v${VERSION}"
DIST="$ROOT/dist"
STAGE="$(mktemp -d)"

cleanup() {
    rm -rf "$STAGE"
}
trap cleanup EXIT

mkdir -p "$DIST" "$STAGE/$NAME"

(
    cd "$ROOT"
    tar \
        --exclude='.git' \
        --exclude='dist' \
        --exclude='*.log' \
        -cf - .
) | (
    cd "$STAGE/$NAME"
    tar -xf -
)

tar -C "$STAGE" -czf "$DIST/${NAME}.tar.gz" "$NAME"

python3 - "$STAGE" "$DIST" "$NAME" <<'PY'
from pathlib import Path
import sys
import zipfile

stage = Path(sys.argv[1])
dist = Path(sys.argv[2])
name = sys.argv[3]
root = stage / name
out = dist / f"{name}.zip"

with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(root.rglob("*")):
        if path.is_dir():
            continue
        arcname = Path(name) / path.relative_to(root)
        info = zipfile.ZipInfo(str(arcname))
        info.create_system = 3
        mode = path.stat().st_mode & 0o777
        info.external_attr = mode << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        zf.writestr(info, path.read_bytes())
PY

(
    cd "$DIST"
    sha256sum "${NAME}.tar.gz" "${NAME}.zip" > "${NAME}.sha256"
)

echo "[OK] Created:"
echo "  $DIST/${NAME}.tar.gz"
echo "  $DIST/${NAME}.zip"
echo "  $DIST/${NAME}.sha256"
