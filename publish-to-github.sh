#!/usr/bin/env bash
set -Eeuo pipefail

VISIBILITY="${1:-public}"
REPOSITORY="${2:-kali-awus1900-deploy}"
DESCRIPTION="Resilient ALFA AWUS1900/RTL8814AU deployment for Kali Linux with safe DKMS fallback."
VERSION="$(awk -F'"' '/^VERSION=/{print $2; exit}' awus1900-deploy.sh)"

case "$VISIBILITY" in
    public|private|internal)
        ;;
    *)
        echo "Usage: $0 {public|private|internal} [OWNER/REPOSITORY]" >&2
        exit 2
        ;;
esac

if ! command -v git >/dev/null 2>&1 || ! command -v gh >/dev/null 2>&1; then
    echo "[ERROR] Git and GitHub CLI are required." >&2
    echo "Install them from GitHub's official signed repository:" >&2
    echo "  ./scripts/install-github-cli.sh" >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "[+] GitHub authentication is required."
    gh auth login
fi

# Configure Git to obtain HTTPS credentials from the authenticated GitHub CLI.
gh auth setup-git

LOGIN="$(gh api user --jq '.login')"
USER_ID="$(gh api user --jq '.id')"
DISPLAY_NAME="$(gh api user --jq '.name // .login')"

# Repository-local configuration requires an initialized working tree.
if [[ ! -d .git ]]; then
    echo "[+] Initializing local Git repository..."
    git init -b main
fi

if [[ -z "$(git config --local --get user.name || true)" ]]; then
    git config --local user.name "$DISPLAY_NAME"
fi

if [[ -z "$(git config --local --get user.email || true)" ]]; then
    git config --local user.email "${USER_ID}+${LOGIN}@users.noreply.github.com"
fi

git add --all

if ! git diff --cached --quiet; then
    git commit -m "Release v${VERSION}"
fi

if git remote get-url origin >/dev/null 2>&1; then
    echo "[+] Existing origin detected: $(git remote get-url origin)"
    git push -u origin main
else
    visibility_flag="--${VISIBILITY}"
    gh repo create "$REPOSITORY" \
        "$visibility_flag" \
        --source=. \
        --remote=origin \
        --push \
        --description "$DESCRIPTION"
fi

FULL_NAME="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
HTML_URL="$(gh repo view --json url --jq '.url')"
CLONE_URL="${HTML_URL}.git"

gh repo edit "$FULL_NAME" \
    --add-topic kali-linux,alfa,awus1900,rtl8814au,rtw88,dkms,wireless,monitor-mode,virtualbox,linux \
    --delete-branch-on-merge

if grep -q 'https://github.com/OWNER/kali-awus1900-deploy.git' README.md; then
    sed -i "s|https://github.com/OWNER/kali-awus1900-deploy.git|${CLONE_URL}|g" README.md
    git add README.md
    if ! git diff --cached --quiet; then
        git commit -m "Set repository clone URL"
        git push
    fi
fi

TAG="v${VERSION}"
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    git tag -a "$TAG" -m "Release ${TAG}"
fi
git push origin "$TAG"

echo
echo "[OK] Published: ${HTML_URL}"
echo "[OK] Clone URL: ${CLONE_URL}"
echo
echo "Optional GitHub release:"
echo "  gh release create ${TAG} --generate-notes --title '${TAG}'"
