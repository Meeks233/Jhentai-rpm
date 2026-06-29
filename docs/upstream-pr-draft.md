<!--
This is a PREPARED, UN-SUBMITTED pull request to the upstream author.
Do NOT commit this file to a branch you send upstream — it lives only on your fork.

When you decide to propose it, run:

  gh pr create \
    --repo jiangtian616/JHenTai \
    --base master \
    --head Meeks233:fedora-dnf-readme \
    --title "docs: add community-maintained Fedora/dnf install instructions" \
    --body-file docs/upstream-pr-draft.md

(or open https://github.com/jiangtian616/JHenTai/compare/master...Meeks233:fedora-dnf-readme )
-->

## What

Adds a short **Fedora / dnf** install section to the README (and a linked
`docs/fedora-repo.md`), pointing at a community-maintained, GPG-signed dnf
repository:

```bash
sudo rpm --import https://meeks233.github.io/Jhentai-rpm/fedora/RPM-GPG-KEY-jhentai
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo https://meeks233.github.io/Jhentai-rpm/fedora/jhentai.repo
sudo dnf install jhentai
```

## Why

Fedora users currently have to grab a `.deb`/AppImage manually with no update
path. This gives them a real repo (`dnf install` / `dnf upgrade`) with signed
packages and signed metadata.

## Notes

- The repo is **community-maintained by @Meeks233**, built from this project's
  sources (Apache-2.0). The README text states it is unofficial — no claim of
  endorsement.
- This PR is **docs only**; it changes no build or app code.
- Packages and metadata are signed; the `.repo` ships `gpgcheck=1` +
  `repo_gpgcheck=1`.
- Happy to also add the same lines to `README_cn.md` / `README_kr.md` if you'd
  like.
