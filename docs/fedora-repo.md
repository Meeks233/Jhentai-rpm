# JHenTai on Fedora (dnf)

This fork hosts a community-maintained, GPG-signed **dnf repository** for
JHenTai, so you can install and keep it updated like any other package.

> Community-maintained build, linked from the upstream project's README.
> Source: <https://github.com/jiangtian616/JHenTai> (Apache-2.0).

## Install

```bash
sudo rpm --import https://meeks233.github.io/Jhentai-rpm/fedora/RPM-GPG-KEY-jhentai
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo \
  https://meeks233.github.io/Jhentai-rpm/fedora/jhentai.repo
sudo dnf install jhentai
```

Importing the key first lets `repo_gpgcheck` validate the repository metadata on
the very first refresh.

## Update / remove

```bash
sudo dnf upgrade jhentai     # update to the latest release
sudo dnf remove jhentai      # uninstall
```

## Trust

- Packages and repository metadata are signed with the key
  `B2B0 4D21 1288 5367 23CD 87F1 96E1 8262 CDE2 2A1A`.
- The `.repo` ships with `gpgcheck=1` and `repo_gpgcheck=1`, so dnf refuses
  unsigned or tampered packages/metadata.

## Hosting model

Packages live as assets on a rolling GitHub Release (tag `repo`); the dnf
metadata on GitHub Pages points each package's location at the release download
URL. So dnf reads the small signed metadata from Pages and downloads the rpm
**directly from the release** — no rpm bytes are ever committed to git, and the
release provides the package storage and bandwidth.

## For maintainers

The repo is produced from the fork with a single command:

```bash
./distribute.sh
```

which syncs upstream, builds the host-arch rpm (`rpm.sh`), signs and uploads it
to the rolling release (`tools/fedora/sign-and-upload.sh`), then regenerates and
publishes the metadata (`tools/fedora/build-metadata.sh`). `distribute.sh`
builds the host architecture only.

### Fully automated (no local steps)

`.github/workflows/sync-and-publish.yml` runs daily: it merges the upstream
author's latest changes (`tools/fedora/sync-upstream.sh`) and, whenever the app
version moves, calls `.github/workflows/fedora_repo.yml` to build **x86_64 +
aarch64** and republish the repo. Trigger it by hand from the Actions tab
("Run workflow", optionally forcing a rebuild). Nothing on a maintainer's
machine is required; users just get the update via `dnf upgrade`.
