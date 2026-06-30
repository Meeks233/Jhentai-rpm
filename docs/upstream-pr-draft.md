<!--
This is a PREPARED, UN-SUBMITTED pull request to the upstream author.
It lives only on your fork (master); the PR branch is `fedora-dnf-readme`,
which contains ONLY the README change (docs-only, inside "Install for Linux").

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

Adds a few lines to the **"Install for Linux"** section of the README pointing
Fedora / dnf users at a community-maintained, GPG-signed dnf repository:

```bash
sudo rpm --import https://meeks233.github.io/Jhentai-rpm/fedora/RPM-GPG-KEY-jhentai
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo https://meeks233.github.io/Jhentai-rpm/fedora/jhentai.repo
sudo dnf install jhentai
```

## Why

Fedora users currently have to grab a `.deb`/AppImage by hand with no update
path. This gives them a real repo (`dnf install` / `dnf upgrade`) with signed
packages and signed metadata, for both x86_64 and aarch64.

## Notes

- **Docs-only PR** — one README hunk, no build or app-code changes.
- The repository is **community-maintained by @Meeks233**, built from this
  project's sources (Apache-2.0). Remove it any time if you'd prefer not to
  link it.
- Packages and metadata are GPG-signed; the `.repo` ships `gpgcheck=1` +
  `repo_gpgcheck=1`.
- Happy to add the same lines to `README_cn.md` / `README_kr.md` if you want.

---

## 供原作者审阅的新增开源文件（中文）

以下文件全部为新增，均使用 Apache-2.0 许可证，只存在于 fork
`Meeks233/Jhentai-rpm` 中，**不属于本 PR**（本 PR 只改 README 三个语言版本）。
列在这里方便你核对：链接背后没有任何隐藏内容，它是一个自包含的打包/分发层，
**原封不动地构建你发布的源码**，并用维护者自己的密钥签名。

打包（RPM 本体）
- `linux/assets/rpm/jhentai.spec` —— RPM spec：把 Flutter Linux 产物装到
  `/opt/jhentai`，并建立 `/usr/bin/jhentai` 软链（与现有 Debian 打包一致），
  `Requires: gtk3, webkit2gtk4.1`，并打包 LICENSE。
- `rpm.sh` —— `flutter build linux` + `rpmbuild`，产出 `.rpm`。
- `linux/assets/rpm/jhentai.repo` —— 用户安装的 dnf 仓库文件
  （`gpgcheck=1` + `repo_gpgcheck=1`）。
- `linux/assets/rpm/RPM-GPG-KEY-jhentai` —— 维护者的**公钥**
  （私钥只存在于 GitHub Actions secrets，永不外泄、永不入库）。

分发与托管（git 里不存二进制）
- `tools/fedora/sign-and-upload.sh` —— 对 rpm 签名并上传到 GitHub Release。
- `tools/fedora/build-metadata.sh` —— `createrepo_c` 生成元数据、签名
  `repomd.xml`，仅把元数据发布到 `gh-pages`（rpm 实际从 Release 下载）。

自动化（由发布触发，而非每次提交）
- `tools/fedora/check-upstream-release.sh` —— 仅当**发布 tag** 变化时才动作，
  普通提交不会触发构建。
- `.github/workflows/fedora_repo.yml` —— 构建 x86_64 + aarch64 并发布。
- `.github/workflows/sync-and-publish.yml` —— 每日检查，有新发布才构建发布。
- `distribute.sh` —— 同一套流程的本地一键回退方案。

文档
- `docs/fedora-repo.md` —— 仓库托管架构与安全说明。
- `docs/upstream-pr-draft.md` —— 本 PR 草稿（本文件）。

---

## For your audit — what the downstream repo actually does

Everything below lives ONLY in the fork (`Meeks233/Jhentai-rpm`); none of it is
part of this PR. Listed so you can see there is nothing surprising behind the
link. It is a self-contained packaging/distribution layer that **builds your
released source unmodified** and signs it with the maintainer's own key.

Packaging
- `linux/assets/rpm/jhentai.spec` — RPM spec: installs the Flutter Linux bundle
  under `/opt/jhentai` with a `/usr/bin/jhentai` symlink (mirrors the existing
  Debian packaging), `Requires: gtk3, webkit2gtk4.1`, bundles the LICENSE.
- `rpm.sh` — `flutter build linux` + `rpmbuild` → a `.rpm`.
- `linux/assets/rpm/jhentai.repo` — the dnf repo file users install.
- `linux/assets/rpm/RPM-GPG-KEY-jhentai` — the maintainer's **public** signing
  key (private key never leaves GitHub Actions secrets / the maintainer).

Hosting (no binaries in git)
- Packages are uploaded as assets on a rolling GitHub Release; the dnf metadata
  on GitHub Pages carries an `xml:base` pointing at the release download URL, so
  dnf reads metadata from Pages and pulls rpms straight from Releases.
- `tools/fedora/sign-and-upload.sh` — sign rpm(s), upload to the release.
- `tools/fedora/build-metadata.sh` — `createrepo_c --baseurl <release>`, sign
  `repomd.xml`, publish metadata-only to `gh-pages`.

Automation (release-driven, not commit-driven)
- `tools/fedora/check-upstream-release.sh` — only acts when YOUR latest GitHub
  *release tag* changes; never builds on ordinary commits.
- `.github/workflows/fedora_repo.yml` — builds x86_64 + aarch64 by overlaying
  the upstream release tag's tree onto the packaging branch, then publishes.
- `.github/workflows/sync-and-publish.yml` — daily check → build/publish only
  when a new release appears.
- `distribute.sh` — local one-shot fallback of the same pipeline.

Security posture
- App code is built **verbatim** from your release tag (git checkout of the
  tag); the only added files are the packaging/CI ones above.
- The committed API-secret placeholder is shipped as-is (empty); no secret of
  yours is read or redistributed.
- Signing key: RSA-4096; private key + passphrase exist only as encrypted
  GitHub Actions secrets, never echoed to logs, never committed.
