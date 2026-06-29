#!/usr/bin/env bash
# One-click Fedora/dnf distribution for JHenTai.
#
# Manual fallback for the CI automation (.github/workflows/sync-and-publish.yml).
# Does the whole chain in one shot:
#   1. Overlay the latest upstream RELEASE code onto the working tree.
#   2. Build the Linux .rpm for this host's architecture.
#   3. Sign it and upload it to the rolling GitHub Release (the package store).
#   4. Rebuild the dnf metadata over ALL packages on the release and publish it
#      (metadata only) to gh-pages.
#
# Packages live as release assets and dnf downloads them straight from there;
# only the small signed metadata is served from GitHub Pages. After it finishes,
# users can `dnf install jhentai` from your repo. NOTE: this builds the host
# architecture only (x86_64 here) — arm64 packages come from CI; this script
# leaves any existing arm64 release asset untouched.
#
# Config (env, with sensible defaults):
#   ORIGIN_REMOTE     your fork remote        (default: origin)
#   UPSTREAM_REMOTE   author's repo remote    (default: upstream)
#   BRANCH            code branch to sync     (default: master)
#   PAGES_BRANCH      repo hosting branch     (default: gh-pages)
#   KEEP_VERSIONS     old rpms kept per arch  (default: 5)
#   GPG_NAME          signing key uid         (default: from ~/.config/jhentai-fedora/gpg_name)
#   GPG_PASSPHRASE_FILE  key passphrase file  (default: ~/.config/jhentai-fedora/passphrase)
#   SKIP_UPSTREAM_SYNC=1  skip step 1
set -euo pipefail

repo_root=$(cd "$(dirname "$0")" && pwd)
cd "$repo_root"

ORIGIN_REMOTE=${ORIGIN_REMOTE:-origin}
UPSTREAM_REMOTE=${UPSTREAM_REMOTE:-upstream}
BRANCH=${BRANCH:-master}
PAGES_BRANCH=${PAGES_BRANCH:-gh-pages}
KEEP_VERSIONS=${KEEP_VERSIONS:-5}

CFG="$HOME/.config/jhentai-fedora"
GPG_NAME=${GPG_NAME:-$(cat "$CFG/gpg_name" 2>/dev/null || echo "JHenTai Fedora Repo")}
GPG_PASSPHRASE_FILE=${GPG_PASSPHRASE_FILE:-$CFG/passphrase}

# Make sure flutter is reachable.
if ! command -v flutter >/dev/null 2>&1; then
  [ -x "$HOME/flutter/bin/flutter" ] && export PATH="$HOME/flutter/bin:$PATH"
fi
command -v flutter   >/dev/null || { echo "flutter not found" >&2; exit 1; }
command -v rpmsign   >/dev/null || { echo "rpmsign not found (dnf install rpm-sign)" >&2; exit 1; }
command -v createrepo_c >/dev/null || { echo "createrepo_c not found (dnf install createrepo_c)" >&2; exit 1; }

owner_repo=$(git remote get-url "$ORIGIN_REMOTE" | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')
owner=${owner_repo%%/*}
name=${owner_repo##*/}
owner_lc=$(echo "$owner" | tr '[:upper:]' '[:lower:]')
REPO_BASEURL=${REPO_BASEURL:-https://$owner_lc.github.io/$name/fedora/}

echo "==> Fork:    $owner_repo  (remote: $ORIGIN_REMOTE)"
echo "==> Pages:   $REPO_BASEURL"

# ---------------------------------------------------------------------------
# 1. Overlay the latest upstream RELEASE code (so we package a real release,
#    not whatever happens to be on our packaging branch). Restored at the end.
# ---------------------------------------------------------------------------
overlaid_tag=""
if [ "${SKIP_UPSTREAM_SYNC:-0}" != "1" ] && command -v gh >/dev/null 2>&1; then
  overlaid_tag=$(gh release view -R "${UPSTREAM_SLUG:-jiangtian616/JHenTai}" \
    --json tagName --jq .tagName 2>/dev/null || true)
fi
if [ -n "$overlaid_tag" ]; then
  echo "==> [1/4] Overlaying upstream release $overlaid_tag"
  git remote add upstream https://github.com/jiangtian616/JHenTai 2>/dev/null || true
  git fetch --depth 1 upstream tag "$overlaid_tag"
  git checkout "$overlaid_tag" -- .
  restore_tree() { git checkout HEAD -- . 2>/dev/null || true; }
  trap restore_tree EXIT
else
  echo "==> [1/4] Building current working tree (no overlay)"
fi

# ---------------------------------------------------------------------------
# 2. Build the rpm (host architecture)
# ---------------------------------------------------------------------------
echo "==> [2/4] Building rpm"
bash "$repo_root/rpm.sh"
new_rpm=$(ls -t "$repo_root"/build/linux/*.rpm | head -1)
echo "    built: $(basename "$new_rpm")"

# ---------------------------------------------------------------------------
# 3. Sign + upload the package to the rolling release
#    (arm64 packages, if any, are produced by CI and live in the same release;
#    this step only adds/replaces the host arch and never removes the others)
# ---------------------------------------------------------------------------
echo "==> [3/4] Signing + uploading package to release"
GPG_NAME="$GPG_NAME" GPG_PASSPHRASE_FILE="$GPG_PASSPHRASE_FILE" \
  bash "$repo_root/tools/fedora/sign-and-upload.sh" "$new_rpm"

# ---------------------------------------------------------------------------
# 4. Rebuild metadata over ALL release packages and publish to gh-pages
# ---------------------------------------------------------------------------
echo "==> [4/4] Rebuilding metadata + publishing"
GPG_NAME="$GPG_NAME" GPG_PASSPHRASE_FILE="$GPG_PASSPHRASE_FILE" \
REPO_BASEURL="$REPO_BASEURL" KEEP_VERSIONS="$KEEP_VERSIONS" PAGES_BRANCH="$PAGES_BRANCH" \
  bash "$repo_root/tools/fedora/build-metadata.sh"

# Enable GitHub Pages (idempotent).
if command -v gh >/dev/null 2>&1; then
  gh api -X POST "repos/$owner/$name/pages" \
    -f "source[branch]=$PAGES_BRANCH" -f "source[path]=/" >/dev/null 2>&1 \
  || gh api -X PUT "repos/$owner/$name/pages" \
    -f "source[branch]=$PAGES_BRANCH" -f "source[path]=/" >/dev/null 2>&1 || true
fi

echo
echo "Done. Users can install with:"
echo "  sudo rpm --import ${REPO_BASEURL}RPM-GPG-KEY-jhentai"
echo "  sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo ${REPO_BASEURL}jhentai.repo"
echo "  sudo dnf install jhentai"
