# JHenTai on Fedora (dnf)

This fork hosts a community-maintained, GPG-signed **dnf repository** for
JHenTai, so you can install and keep it updated like any other package.

> Unofficial build. Not affiliated with or endorsed by the original author.
> Source: <https://github.com/jiangtian616/JHenTai> (Apache-2.0).

## Install

```bash
sudo rpm --import https://meeks233.github.io/JHenTai/fedora/RPM-GPG-KEY-jhentai
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo \
  https://meeks233.github.io/JHenTai/fedora/jhentai.repo
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

## For maintainers

The repo is produced from the fork with a single command:

```bash
./distribute.sh
```

which syncs upstream, builds the rpm (`rpm.sh`), signs it, regenerates the dnf
metadata (`tools/fedora/build-fedora-repo.sh`), and publishes to the `gh-pages`
branch. CI does the same automatically on tag pushes
(`.github/workflows/fedora_repo.yml`).
