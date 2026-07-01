#!/usr/bin/env bash
# Decide whether the upstream author has published a NEW RELEASE that we have
# not packaged yet. We track upstream *releases* (tags), not master commits, so
# we only build when a real version ships — never on every upstream commit.
#
# Env:
#   UPSTREAM_SLUG  upstream owner/name   (default: jiangtian616/JHenTai)
#   FORK_SLUG      our owner/name        (default: derived from origin)
#   RELEASE_TAG    rolling release tag   (default: repo)
#   FORCE=1        report changed=true regardless
#
# Outputs (to $GITHUB_OUTPUT when set): changed, tag, version
set -euo pipefail

UPSTREAM_SLUG=${UPSTREAM_SLUG:-jiangtian616/JHenTai}
RELEASE_TAG=${RELEASE_TAG:-repo}
FORK_SLUG=${FORK_SLUG:-$(git remote get-url origin \
  | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')}

# Latest upstream release tag, e.g. v8.0.13+312 or v8.0.14.
upstream_tag=$(gh release view -R "$UPSTREAM_SLUG" --json tagName --jq .tagName)
upstream_ver=$(echo "$upstream_tag" | sed 's/^v//; s/+/./')

# Which upstream release did we last successfully package? We compare TAG-to-TAG
# using a marker stamped in the rolling release body by build-metadata.sh. We do
# NOT derive "served version" from the rpm filename: that carries the pubspec
# build number (e.g. 8.0.14.317), which does not match a tag like "v8.0.14", so
# such a comparison would report "changed" on every run and rebuild endlessly.
last_tag=$(gh release view "$RELEASE_TAG" -R "$FORK_SLUG" --json body --jq '.body' 2>/dev/null \
  | sed -nE 's/^built-upstream-tag:[[:space:]]*([^[:space:]]+).*/\1/p' | head -1 || true)

changed=false
[ "$upstream_tag" != "$last_tag" ] && changed=true
[ "${FORCE:-0}" = "1" ] && changed=true

echo ">> upstream release : $upstream_tag ($upstream_ver)"
echo ">> last packaged tag: ${last_tag:-<none>}"
echo ">> changed=$changed"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "changed=$changed"
    echo "tag=$upstream_tag"
    echo "version=$upstream_ver"
  } >> "$GITHUB_OUTPUT"
fi
