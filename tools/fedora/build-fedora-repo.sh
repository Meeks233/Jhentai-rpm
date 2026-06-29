#!/usr/bin/env bash
# Sign every RPM in a directory, build dnf repo metadata over them, sign the
# metadata, and render the consumer .repo file + a small landing page.
#
# This operates IN PLACE on a "fedora dir" that already contains the .rpm files
# you want published. The caller (distribute.sh / CI) is responsible for
# assembling that set of rpms (e.g. merging the freshly built rpm with the ones
# already live on gh-pages and pruning old versions).
#
# Configuration via environment:
#   FEDORA_DIR            target dir holding *.rpm (required, arg 1)
#   GPG_NAME              signing key uid/id            (default: "JHenTai Fedora Repo")
#   GPG_PASSPHRASE_FILE   passphrase file for the key   (optional; loopback if set)
#   REPO_BASEURL          public URL of FEDORA_DIR      (default: GitHub Pages URL)
#   PUBKEY_FILE           ASCII-armored public key      (default: repo's committed key)
set -euo pipefail

FEDORA_DIR=${1:-${FEDORA_DIR:-}}
if [ -z "${FEDORA_DIR}" ]; then
  echo "usage: build-fedora-repo.sh <fedora_dir>" >&2
  exit 2
fi
FEDORA_DIR=$(cd "$FEDORA_DIR" && pwd)

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)

GPG_NAME=${GPG_NAME:-JHenTai Fedora Repo}
REPO_BASEURL=${REPO_BASEURL:-https://meeks233.github.io/Jhentai-rpm/fedora/}
PUBKEY_FILE=${PUBKEY_FILE:-$repo_root/linux/assets/rpm/RPM-GPG-KEY-jhentai}
GPG_PASSPHRASE_FILE=${GPG_PASSPHRASE_FILE:-}

# Normalise baseurl to end with a single slash.
REPO_BASEURL=${REPO_BASEURL%/}/
gpgkey_url="${REPO_BASEURL}RPM-GPG-KEY-jhentai"

shopt -s nullglob
rpms=("$FEDORA_DIR"/*.rpm)
if [ ${#rpms[@]} -eq 0 ]; then
  echo "No .rpm files found in $FEDORA_DIR" >&2
  exit 1
fi

# Build the loopback flags only when a passphrase file is provided (CI / one-click).
sign_extra_args=""
gpg_loopback=()
if [ -n "$GPG_PASSPHRASE_FILE" ]; then
  sign_extra_args="--pinentry-mode loopback --passphrase-file $GPG_PASSPHRASE_FILE"
  gpg_loopback=(--pinentry-mode loopback --passphrase-file "$GPG_PASSPHRASE_FILE")
fi

echo ">> Signing ${#rpms[@]} package(s) with key '$GPG_NAME'"
for rpm in "${rpms[@]}"; do
  rpmsign --addsign \
    --define "_gpg_name $GPG_NAME" \
    --define "_gpg_sign_cmd_extra_args $sign_extra_args" \
    "$rpm" >/dev/null
  rpm -Kv "$rpm" | sed 's/^/   /'
done

echo ">> Publishing public key"
cp "$PUBKEY_FILE" "$FEDORA_DIR/RPM-GPG-KEY-jhentai"

echo ">> Generating repo metadata (createrepo_c)"
createrepo_c --update --quiet "$FEDORA_DIR"

echo ">> Signing repomd.xml"
rm -f "$FEDORA_DIR/repodata/repomd.xml.asc"
gpg --batch --yes "${gpg_loopback[@]}" -u "$GPG_NAME" \
    --detach-sign --armor "$FEDORA_DIR/repodata/repomd.xml"

echo ">> Rendering jhentai.repo"
cat > "$FEDORA_DIR/jhentai.repo" <<EOF
[jhentai]
name=JHenTai (unofficial Fedora repo)
baseurl=$REPO_BASEURL
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$gpgkey_url
EOF

echo ">> Rendering index.html"
cat > "$FEDORA_DIR/index.html" <<EOF
<!doctype html>
<meta charset="utf-8">
<title>JHenTai &mdash; unofficial Fedora/dnf repo</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:46rem;margin:3rem auto;padding:0 1rem}code,pre{background:#f4f4f4;border-radius:4px}pre{padding:1rem;overflow:auto}</style>
<h1>JHenTai &mdash; unofficial Fedora / dnf repo</h1>
<p>Community-maintained RPM repository for
<a href="https://github.com/jiangtian616/JHenTai">JHenTai</a> (Apache-2.0).
Not affiliated with or endorsed by the original author.</p>
<h2>Install</h2>
<pre>sudo rpm --import ${gpgkey_url}
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo ${REPO_BASEURL}jhentai.repo
sudo dnf install jhentai</pre>
<h2>Update</h2>
<pre>sudo dnf upgrade jhentai</pre>
<p>GPG key fingerprint:
<code>B2B0 4D21 1288 5367 23CD 87F1 96E1 8262 CDE2 2A1A</code></p>
EOF

echo
echo "Repo built at: $FEDORA_DIR"
echo "  packages : ${#rpms[@]}"
echo "  baseurl  : $REPO_BASEURL"
