#!/usr/bin/env bash
# One-click Fedora/dnf distribution for JHenTai.
#
# Does the whole chain in one shot:
#   1. Sync the latest changes from the upstream author into your fork.
#   2. Build the Linux .rpm.
#   3. Merge it with the packages already live on gh-pages and prune old ones.
#   4. Sign packages + metadata and rebuild the dnf repo.
#   5. Push the repo to the gh-pages branch and make sure GitHub Pages is on.
#
# After it finishes, users can `dnf install jhentai` from your repo.
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
# 1. Sync upstream author -> fork
# ---------------------------------------------------------------------------
if [ "${SKIP_UPSTREAM_SYNC:-0}" != "1" ] && git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  echo "==> [1/5] Syncing $UPSTREAM_REMOTE/$BRANCH into $BRANCH"
  git fetch "$UPSTREAM_REMOTE" "$BRANCH"
  git checkout "$BRANCH"
  before=$(git rev-parse HEAD)
  git merge --no-edit "$UPSTREAM_REMOTE/$BRANCH"
  after=$(git rev-parse HEAD)
  if [ "$before" != "$after" ]; then
    echo "    merged upstream changes; pushing $BRANCH to $ORIGIN_REMOTE"
    git push "$ORIGIN_REMOTE" "$BRANCH"
  else
    echo "    already up to date with upstream"
  fi
else
  echo "==> [1/5] Skipping upstream sync"
fi

# ---------------------------------------------------------------------------
# 2. Build the rpm
# ---------------------------------------------------------------------------
echo "==> [2/5] Building rpm"
bash "$repo_root/rpm.sh"
new_rpm=$(ls -t "$repo_root"/build/linux/*.rpm | head -1)
echo "    built: $(basename "$new_rpm")"

# ---------------------------------------------------------------------------
# 3. Assemble gh-pages worktree (existing packages + new, pruned)
# ---------------------------------------------------------------------------
echo "==> [3/5] Assembling repo from $PAGES_BRANCH"
worktree="$repo_root/build/gh-pages"
git worktree remove --force "$worktree" 2>/dev/null || true
rm -rf "$worktree"
git fetch "$ORIGIN_REMOTE" "$PAGES_BRANCH" 2>/dev/null || true
if git rev-parse --verify "$ORIGIN_REMOTE/$PAGES_BRANCH" >/dev/null 2>&1; then
  git worktree add "$worktree" "$ORIGIN_REMOTE/$PAGES_BRANCH"
else
  git worktree add --detach "$worktree"
  git -C "$worktree" checkout --orphan "$PAGES_BRANCH"
  git -C "$worktree" rm -rf . >/dev/null 2>&1 || true
fi

fedora_dir="$worktree/fedora"
mkdir -p "$fedora_dir"
cp -f "$new_rpm" "$fedora_dir/"

# Prune: keep newest KEEP_VERSIONS per architecture.
for arch in $(ls "$fedora_dir"/*.rpm 2>/dev/null | sed -E 's/.*\.([a-z0-9_]+)\.rpm/\1/' | sort -u); do
  ls "$fedora_dir"/*."$arch".rpm 2>/dev/null | sort -V | head -n "-$KEEP_VERSIONS" | while read -r old; do
    echo "    pruning $(basename "$old")"
    rm -f "$old"
  done
done

# ---------------------------------------------------------------------------
# 4. Sign + build metadata
# ---------------------------------------------------------------------------
echo "==> [4/5] Signing + indexing"
GPG_NAME="$GPG_NAME" \
GPG_PASSPHRASE_FILE="$GPG_PASSPHRASE_FILE" \
REPO_BASEURL="$REPO_BASEURL" \
  bash "$repo_root/tools/fedora/build-fedora-repo.sh" "$fedora_dir"

# ---------------------------------------------------------------------------
# 5. Publish to gh-pages + ensure Pages enabled
# ---------------------------------------------------------------------------
echo "==> [5/5] Publishing to $ORIGIN_REMOTE/$PAGES_BRANCH"
touch "$worktree/.nojekyll"
git -C "$worktree" add -A
if git -C "$worktree" diff --cached --quiet; then
  echo "    nothing changed"
else
  app_version=$(head -n 5 "$repo_root/pubspec.yaml" | tail -n 1 | cut -d ' ' -f 2)
  git -C "$worktree" -c user.name="JHenTai Fedora Bot" \
                     -c user.email="shadowblaze_kai@icloud.com" \
                     commit -q -m "Publish Fedora repo for $app_version"
  git -C "$worktree" push "$ORIGIN_REMOTE" "HEAD:$PAGES_BRANCH"
fi

# Enable GitHub Pages (idempotent).
if command -v gh >/dev/null 2>&1; then
  gh api -X POST "repos/$owner/$name/pages" \
    -f "source[branch]=$PAGES_BRANCH" -f "source[path]=/" >/dev/null 2>&1 \
  || gh api -X PUT "repos/$owner/$name/pages" \
    -f "source[branch]=$PAGES_BRANCH" -f "source[path]=/" >/dev/null 2>&1 || true
fi

git worktree remove --force "$worktree" 2>/dev/null || true

echo
echo "Done. Users can install with:"
echo "  sudo rpm --import ${REPO_BASEURL}RPM-GPG-KEY-jhentai"
echo "  sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo ${REPO_BASEURL}jhentai.repo"
echo "  sudo dnf install jhentai"
