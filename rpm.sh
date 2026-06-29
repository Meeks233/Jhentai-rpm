#!/usr/bin/env bash
# Build a Fedora / dnf (.rpm) package for JHenTai.
#
# Mirrors linux.sh (which produces a zip) and the .deb packaging in
# linux/assets/DEBIAN, producing build/linux/*.rpm.
#
# Requires: flutter, rpmbuild (rpm-build), and the Linux desktop build deps
# (clang, cmake, ninja-build, gtk3-devel, webkit2gtk4.1-devel).
set -e

repo_root=$(cd "$(dirname "$0")" && pwd)
cd "$repo_root"

version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)
# RPM versions may not contain '+'; turn 8.0.13+315 into 8.0.13.315.
rpm_version=$(echo "$version" | tr '+' '.')

# Map uname arch to Flutter's bundle directory name.
machine=$(uname -m)
case "$machine" in
  x86_64)  flutter_arch=x64 ;;
  aarch64) flutter_arch=arm64 ;;
  *)       flutter_arch=$machine ;;
esac

# Compile the Linux release bundle.
flutter build linux --release -t lib/src/main.dart

bundle_dir="$repo_root/build/linux/$flutter_arch/release/bundle"
if [ ! -d "$bundle_dir" ]; then
  echo "Bundle not found at $bundle_dir" >&2
  exit 1
fi

# Set up an isolated rpmbuild tree under build/linux.
rpm_top="$repo_root/build/linux/rpmbuild"
rm -rf "$rpm_top"
mkdir -p "$rpm_top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# Allow the bundle's $ORIGIN/lib rpath through rpmbuild's QA check.
export QA_RPATHS=$(( 0x0001|0x0010 ))

rpmbuild -bb \
  --define "_topdir $rpm_top" \
  --define "_version $rpm_version" \
  --define "_bundledir $bundle_dir" \
  --define "_desktopfile $repo_root/linux/assets/top.jtmonster.jhentai.desktop" \
  --define "_iconfile $repo_root/assets/icon/JHenTai_512.png" \
  --define "_licensefile $repo_root/LICENSE" \
  "$repo_root/linux/assets/rpm/jhentai.spec"

# Copy the built rpm(s) next to the deb output location.
mkdir -p "$repo_root/build/linux"
find "$rpm_top/RPMS" -name '*.rpm' -exec cp {} "$repo_root/build/linux/" \;

echo
echo "Built RPM(s):"
find "$repo_root/build/linux" -maxdepth 1 -name '*.rpm'
