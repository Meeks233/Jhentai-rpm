#!/usr/bin/env bash
# Sync the fork's branch with the upstream author and report whether a new
# app version arrived. Designed to run unattended in GitHub Actions.
#
# Our changes to the fork are purely additive (new files) except for two
# upstream workflow files we intentionally keep deleted; this script
# auto-resolves that one known case so the merge never needs a human.
#
# Env:
#   UPSTREAM_URL   upstream repo            (default: jiangtian616/JHenTai)
#   BRANCH         branch to track          (default: master)
#   ORIGIN_REMOTE  fork remote to push to   (default: origin)
#   FORCE=1        report changed=true even if the version did not move
#
# Outputs (to $GITHUB_OUTPUT when set): changed, version, sha
set -euo pipefail

UPSTREAM_URL=${UPSTREAM_URL:-https://github.com/jiangtian616/JHenTai}
BRANCH=${BRANCH:-master}
ORIGIN_REMOTE=${ORIGIN_REMOTE:-origin}

# Files we deliberately keep removed from the fork. If upstream modifies them a
# merge would raise a modify/delete conflict; we always resolve to "deleted".
KEEP_DELETED=(
  .github/workflows/build_publish.yml
  .github/workflows/fastlane.yml
)

app_version() { head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2; }

git remote add upstream "$UPSTREAM_URL" 2>/dev/null \
  || git remote set-url upstream "$UPSTREAM_URL"
git fetch --quiet upstream "$BRANCH"

before_head=$(git rev-parse HEAD)
before_ver=$(app_version)

# Merge upstream, tolerating the known modify/delete case.
git merge --no-commit --no-ff "upstream/$BRANCH" || true
git rm -q --ignore-unmatch -f "${KEEP_DELETED[@]}" >/dev/null 2>&1 || true

if git ls-files -u | grep -q .; then
  echo "ERROR: unexpected merge conflict — needs a human:" >&2
  git ls-files -u | awk '{print "  "$4}' | sort -u >&2
  git merge --abort 2>/dev/null || git reset --hard "$before_head"
  exit 3
fi

if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  git -c user.name="JHenTai Fedora Bot" -c user.email="shadowblaze_kai@icloud.com" \
      commit --no-edit -q
fi

after_head=$(git rev-parse HEAD)
after_ver=$(app_version)

# Push only if history actually advanced.
if [ "$before_head" != "$after_head" ]; then
  echo ">> Pushing synced $BRANCH to $ORIGIN_REMOTE"
  git push "$ORIGIN_REMOTE" "HEAD:$BRANCH"
else
  echo ">> Already up to date with upstream"
fi

changed=false
[ "$before_ver" != "$after_ver" ] && changed=true
[ "${FORCE:-0}" = "1" ] && changed=true

echo ">> version: $before_ver -> $after_ver (changed=$changed)"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "changed=$changed"
    echo "version=$after_ver"
    echo "sha=$after_head"
  } >> "$GITHUB_OUTPUT"
fi
