# 📦 JHenTai on Fedora / dnf

[English](#english) · [日本語](#日本語) · [简体中文](#简体中文) · [한국어](#한국어)

A community-maintained, GPG-signed **dnf repository** for
[JHenTai](https://github.com/jiangtian616/JHenTai). Install it once, then keep
it updated with `dnf upgrade` like any other package. Supports x86_64 and
aarch64.

## English

```bash
sudo rpm --import https://meeks233.github.io/Jhentai-rpm/fedora/RPM-GPG-KEY-jhentai
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo https://meeks233.github.io/Jhentai-rpm/fedora/jhentai.repo
sudo dnf install -y jhentai
```

Update later with `sudo dnf upgrade jhentai`.

## 日本語

```bash
sudo rpm --import https://meeks233.github.io/Jhentai-rpm/fedora/RPM-GPG-KEY-jhentai
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo https://meeks233.github.io/Jhentai-rpm/fedora/jhentai.repo
sudo dnf install -y jhentai
```

更新は `sudo dnf upgrade jhentai` で行えます。

## 简体中文

```bash
sudo rpm --import https://meeks233.github.io/Jhentai-rpm/fedora/RPM-GPG-KEY-jhentai
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo https://meeks233.github.io/Jhentai-rpm/fedora/jhentai.repo
sudo dnf install -y jhentai
```

之后使用 `sudo dnf upgrade jhentai` 更新。

## 한국어

```bash
sudo rpm --import https://meeks233.github.io/Jhentai-rpm/fedora/RPM-GPG-KEY-jhentai
sudo curl -fsSL -o /etc/yum.repos.d/jhentai.repo https://meeks233.github.io/Jhentai-rpm/fedora/jhentai.repo
sudo dnf install -y jhentai
```

이후 `sudo dnf upgrade jhentai` 로 업데이트하세요.

---

For the app itself, other platforms (Android / iOS / Windows / macOS / Linux),
and full documentation, see the original repository:
**https://github.com/jiangtian616/JHenTai**
