#!/usr/bin/env bash
# Sign the given rpm(s) and upload them to the rolling GitHub Release that
# backs the dnf repo. The actual package bytes live as release assets (not in
# git / gh-pages); dnf downloads them directly from the release URL.
#
# Usage:  sign-and-upload.sh <file.rpm> [more.rpm ...]
# Env:
#   GPG_NAME             signing key uid       (default: "JHenTai Fedora Repo")
#   GPG_PASSPHRASE_FILE  passphrase file       (optional; loopback if set)
#   RELEASE_TAG          rolling release tag   (default: repo)
#   REPO_SLUG            owner/name            (default: derived from origin)
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)

GPG_NAME=${GPG_NAME:-JHenTai Fedora Repo}
GPG_PASSPHRASE_FILE=${GPG_PASSPHRASE_FILE:-}
RELEASE_TAG=${RELEASE_TAG:-repo}
REPO_SLUG=${REPO_SLUG:-$(git -C "$repo_root" remote get-url origin \
  | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')}

[ $# -ge 1 ] || { echo "usage: sign-and-upload.sh <file.rpm> ..." >&2; exit 2; }

sign_extra_args=""
[ -n "$GPG_PASSPHRASE_FILE" ] && \
  sign_extra_args="--pinentry-mode loopback --passphrase-file $GPG_PASSPHRASE_FILE"

echo ">> Signing $# package(s) with key '$GPG_NAME'"
for rpm in "$@"; do
  rpmsign --addsign \
    --define "_gpg_name $GPG_NAME" \
    --define "_gpg_sign_cmd_extra_args $sign_extra_args" \
    "$rpm" >/dev/null
  echo "   signed $(basename "$rpm")"
done

# Make sure the rolling release exists.
if ! gh release view "$RELEASE_TAG" -R "$REPO_SLUG" >/dev/null 2>&1; then
  echo ">> Creating rolling release '$RELEASE_TAG' on $REPO_SLUG"
  gh release create "$RELEASE_TAG" -R "$REPO_SLUG" \
    --title "Fedora dnf repository (packages)" \
    --notes "RPM packages served by the JHenTai dnf repo. Install via dnf, not by hand: https://${REPO_SLUG%%/*}.github.io/${REPO_SLUG##*/}/fedora/" \
    --prerelease >/dev/null
fi

echo ">> Uploading to release '$RELEASE_TAG'"
for rpm in "$@"; do
  gh release upload "$RELEASE_TAG" "$rpm" -R "$REPO_SLUG" --clobber
  echo "   uploaded $(basename "$rpm")"
done
