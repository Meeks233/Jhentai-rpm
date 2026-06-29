# RPM spec for JHenTai (Fedora / dnf).
#
# This packages a pre-built Flutter Linux release bundle. The bundle path,
# version, desktop file and icon are passed in via --define from rpm.sh, e.g.:
#
#   rpmbuild -bb \
#     --define "_version 8.0.13.315" \
#     --define "_bundledir /abs/path/to/build/linux/x64/release/bundle" \
#     --define "_desktopfile /abs/path/to/linux/assets/top.jtmonster.jhentai.desktop" \
#     --define "_iconfile /abs/path/to/assets/icon/JHenTai_512.png" \
#     --define "_licensefile /abs/path/to/LICENSE" \
#     linux/assets/rpm/jhentai.spec
#
# Layout mirrors the Debian package: files live under /opt/jhentai with a
# symlink in the bindir.

# The bundle ships its own Flutter/plugin .so files and an $ORIGIN/lib rpath.
# Skip auto dependency generation, debuginfo extraction and rpath checks so the
# pre-built binaries are packaged as-is.
AutoReqProv: no
%global debug_package %{nil}
%global __brp_check_rpaths %{nil}
%global __requires_exclude ^lib.*\\.so.*$
%global __provides_exclude ^lib.*\\.so.*$

Name:           jhentai
Version:        %{_version}
Release:        1%{?dist}
Summary:        A cross-platform app made for e-hentai & exhentai by Flutter

License:        Apache-2.0
URL:            https://github.com/jiangtian616/JHenTai

# Runtime dependencies (Fedora package names).
Requires:       gtk3
Requires:       webkit2gtk4.1

%description
JHenTai is a cross-platform app made for e-hentai & exhentai by Flutter,
targeting Android, iOS, Windows, macOS and Linux.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/jhentai
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/512x512/apps
mkdir -p %{buildroot}%{_datadir}/licenses/jhentai

cp -r %{_bundledir}/* %{buildroot}/opt/jhentai/
ln -sf /opt/jhentai/jhentai %{buildroot}%{_bindir}/jhentai

install -m 0644 %{_desktopfile} %{buildroot}%{_datadir}/applications/top.jtmonster.jhentai.desktop
install -m 0644 %{_iconfile} %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/top.jtmonster.jhentai.png

install -m 0644 %{_licensefile} %{buildroot}%{_datadir}/licenses/jhentai/LICENSE

%files
%license %{_datadir}/licenses/jhentai/LICENSE
/opt/jhentai
%{_bindir}/jhentai
%{_datadir}/applications/top.jtmonster.jhentai.desktop
%{_datadir}/icons/hicolor/512x512/apps/top.jtmonster.jhentai.png

%post
update-desktop-database %{_datadir}/applications &>/dev/null || true
touch --no-create %{_datadir}/icons/hicolor &>/dev/null || true

%postun
update-desktop-database %{_datadir}/applications &>/dev/null || true
if [ $1 -eq 0 ] ; then
    touch --no-create %{_datadir}/icons/hicolor &>/dev/null || true
    gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || true
fi
