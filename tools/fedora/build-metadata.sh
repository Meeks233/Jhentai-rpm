#!/usr/bin/env bash
# Rebuild the dnf repo metadata over ALL packages currently attached to the
# rolling release, sign it, and publish ONLY the metadata to gh-pages.
#
# The package <location> entries carry an xml:base pointing at the release's
# download URL, so dnf fetches the rpms straight from GitHub Releases while
# reading the small metadata from GitHub Pages. No rpm bytes ever land in git.
#
# Env:
#   GPG_NAME             signing key uid       (default: "JHenTai Fedora Repo")
#   GPG_PASSPHRASE_FILE  passphrase file       (optional; loopback if set)
#   RELEASE_TAG          rolling release tag   (default: repo)
#   REPO_SLUG            owner/name            (default: derived from origin)
#   REPO_BASEURL         public Pages URL of the metadata dir
#   PUBKEY_FILE          armored public key    (default: committed key)
#   KEEP_VERSIONS        rpms kept per arch    (default: 5)
#   PAGES_BRANCH         hosting branch        (default: gh-pages)
#   PUBLISH=0            build metadata but skip the gh-pages push
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)

GPG_NAME=${GPG_NAME:-JHenTai Fedora Repo}
GPG_PASSPHRASE_FILE=${GPG_PASSPHRASE_FILE:-}
RELEASE_TAG=${RELEASE_TAG:-repo}
KEEP_VERSIONS=${KEEP_VERSIONS:-5}
PAGES_BRANCH=${PAGES_BRANCH:-gh-pages}
PUBKEY_FILE=${PUBKEY_FILE:-$repo_root/linux/assets/rpm/RPM-GPG-KEY-jhentai}
REPO_SLUG=${REPO_SLUG:-$(git -C "$repo_root" remote get-url origin \
  | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')}
owner=${REPO_SLUG%%/*}; name=${REPO_SLUG##*/}
owner_lc=$(echo "$owner" | tr '[:upper:]' '[:lower:]')
REPO_BASEURL=${REPO_BASEURL:-https://$owner_lc.github.io/$name/fedora/}
REPO_BASEURL=${REPO_BASEURL%/}/
release_base="https://github.com/$REPO_SLUG/releases/download/$RELEASE_TAG/"

gpg_loopback=()
[ -n "$GPG_PASSPHRASE_FILE" ] && \
  gpg_loopback=(--pinentry-mode loopback --passphrase-file "$GPG_PASSPHRASE_FILE")

# --- Prune old assets on the release (keep newest N per arch) ---------------
mapfile -t assets < <(gh release view "$RELEASE_TAG" -R "$REPO_SLUG" \
  --json assets --jq '.assets[].name' 2>/dev/null | grep '\.rpm$' || true)
if [ ${#assets[@]} -eq 0 ]; then
  echo "No rpm assets on release '$RELEASE_TAG'; nothing to do." >&2
  exit 1
fi
for arch in $(printf '%s\n' "${assets[@]}" | sed -E 's/.*\.([a-z0-9_]+)\.rpm/\1/' | sort -u); do
  printf '%s\n' "${assets[@]}" | grep "\.$arch\.rpm\$" | sort -V | head -n "-$KEEP_VERSIONS" \
  | while read -r old; do
      echo ">> Pruning old asset $old"
      gh release delete-asset "$RELEASE_TAG" "$old" -R "$REPO_SLUG" -y || true
    done
done

# --- Download the surviving packages and index them -------------------------
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
echo ">> Downloading current packages from release"
gh release download "$RELEASE_TAG" -R "$REPO_SLUG" -p '*.rpm' -D "$work"
echo "   $(ls "$work"/*.rpm | wc -l) package(s)"

echo ">> Generating metadata (packages served from $release_base)"
createrepo_c --baseurl "$release_base" --quiet "$work"

echo ">> Signing repomd.xml"
gpg --batch --yes "${gpg_loopback[@]}" -u "$GPG_NAME" \
    --detach-sign --armor "$work/repodata/repomd.xml"

# --- Assemble the publish tree (metadata only, no rpms) ---------------------
pub="$repo_root/build/fedora-pages/fedora"
rm -rf "$repo_root/build/fedora-pages"; mkdir -p "$pub"
cp -r "$work/repodata" "$pub/"
cp "$PUBKEY_FILE" "$pub/RPM-GPG-KEY-jhentai"
gpgkey_url="${REPO_BASEURL}RPM-GPG-KEY-jhentai"

cat > "$pub/jhentai.repo" <<EOF
[jhentai]
name=JHenTai (Fedora repo)
baseurl=$REPO_BASEURL
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$gpgkey_url
# Re-check for new packages twice a day. Upstream ships ~monthly and our
# publisher only polls every 4h, so hourly client revalidation would be waste;
# 12h still beats dnf's 48h default and surfaces a release the same day.
metadata_expire=12h
EOF

cat > "$pub/index.html" <<EOF
<!doctype html>
<meta charset="utf-8">
<title>JHenTai &mdash; Fedora/dnf repo</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:46rem;margin:3rem auto;padding:0 1rem}code,pre{background:#f4f4f4;border-radius:4px}pre{padding:1rem;overflow:auto}</style>
<h1>JHenTai &mdash; Fedora / dnf repo</h1>
<p>Community-maintained RPM repository for
<a href="https://github.com/jiangtian616/JHenTai">JHenTai</a> (Apache-2.0),
linked from the upstream project's README.
Packages are pulled by dnf directly from GitHub Releases.</p>
<h2>Install</h2>
<pre>sudo rpm --import ${gpgkey_url}
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo ${REPO_BASEURL}jhentai.repo
sudo dnf install jhentai</pre>
<h2>Update</h2>
<pre>sudo dnf upgrade jhentai</pre>
<p>GPG key fingerprint:
<code>B2B0 4D21 1288 5367 23CD 87F1 96E1 8262 CDE2 2A1A</code></p>
EOF
touch "$repo_root/build/fedora-pages/.nojekyll"

echo ">> Metadata ready at $pub"
[ "${PUBLISH:-1}" = "1" ] || { echo "PUBLISH=0, skipping gh-pages push"; exit 0; }

# --- Publish (force a fresh single-commit branch: metadata is tiny and fully
#     regenerated every run, so we keep no history and stay bloat-free) -------
echo ">> Publishing metadata to $PAGES_BRANCH"
wt="$repo_root/build/gh-pages-wt"
tmp_branch="_fedora_pub_$$"
git -C "$repo_root" worktree remove --force "$wt" 2>/dev/null || true
rm -rf "$wt"
git -C "$repo_root" worktree prune
# Use a unique throwaway branch to avoid colliding with any existing local
# gh-pages branch/worktree, then force-push it onto the real PAGES_BRANCH.
git -C "$repo_root" worktree add --force --detach "$wt" >/dev/null
git -C "$wt" checkout --orphan "$tmp_branch" >/dev/null
git -C "$wt" reset -q
find "$wt" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$repo_root/build/fedora-pages/." "$wt/"
git -C "$wt" add -A
git -C "$wt" -c user.name="JHenTai Fedora Bot" -c user.email="shadowblaze_kai@icloud.com" \
    commit -q -m "Publish dnf metadata"
git -C "$wt" push -f origin "HEAD:$PAGES_BRANCH"
git -C "$repo_root" worktree remove --force "$wt"
git -C "$repo_root" branch -D "$tmp_branch" >/dev/null 2>&1 || true

# Record which upstream release these packages correspond to, so the detector
# (check-upstream-release.sh) can compare tag-to-tag. Stamp it into the rolling
# release body only when we actually know the tag (guard against dispatch on a
# branch, where the ref name is not a version tag).
if [ -n "${BUILT_UPSTREAM_TAG:-}" ] && [[ "$BUILT_UPSTREAM_TAG" == v* ]]; then
  echo ">> Recording built-upstream-tag: $BUILT_UPSTREAM_TAG"
  body=$(gh release view "$RELEASE_TAG" -R "$REPO_SLUG" --json body --jq '.body' 2>/dev/null || true)
  body=$(printf '%s\n' "$body" | grep -v '^built-upstream-tag:' || true)
  body=$(printf '%s\nbuilt-upstream-tag: %s\n' "$body" "$BUILT_UPSTREAM_TAG")
  gh release edit "$RELEASE_TAG" -R "$REPO_SLUG" --notes "$body" >/dev/null
fi
echo ">> Done."
