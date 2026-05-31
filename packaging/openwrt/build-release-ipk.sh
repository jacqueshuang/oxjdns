#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  build-release-ipk.sh --arch <openwrt-arch> --binary <oxidns> --webui <dir> --output <dir>

Builds release .ipk files from an already-built musl OxiDNS binary and WebUI
assets. This is intended for GitHub Release packaging where rebuilding LuCI
dependencies inside the OpenWrt SDK is unnecessary.
USAGE
}

arch=""
binary=""
webui_dir=""
output_dir=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --arch)
      arch="${2:-}"
      shift 2
      ;;
    --binary)
      binary="${2:-}"
      shift 2
      ;;
    --webui)
      webui_dir="${2:-}"
      shift 2
      ;;
    --output)
      output_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "$arch" ] || [ -z "$binary" ] || [ -z "$webui_dir" ] || [ -z "$output_dir" ]; then
  usage
  exit 2
fi

if [ ! -x "$binary" ]; then
  echo "OxiDNS binary is missing or not executable: $binary" >&2
  exit 1
fi

if [ ! -d "$webui_dir" ]; then
  echo "OxiDNS WebUI assets not found at: $webui_dir" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
package_dir="$repo_root/packaging/openwrt/oxidns"

pkg_version="$(awk -F:= '/^PKG_VERSION:=/ { print $2; exit }' "$package_dir/Makefile")"
pkg_release="$(awk -F:= '/^PKG_RELEASE:=/ { print $2; exit }' "$package_dir/Makefile")"
version="${OXIDNS_IPK_VERSION:-${pkg_version}-${pkg_release}}"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
timestamp="@${SOURCE_DATE_EPOCH:-0}"

if tar --version 2>/dev/null | grep -qi 'gnu tar'; then
  tar_args=(--format=gnu --numeric-owner --sort=name --mtime="$timestamp")
else
  tar_args=(--format=gnutar --numeric-owner)
fi

installed_size_kb() {
  du -sk "$1" | awk '{ print $1 }'
}

write_archive() {
  local package="$1"
  local package_arch="$2"
  local work_dir="$3"
  local output_file="$output_dir/${package}_${version}_${package_arch}.ipk"

  (
    cd "$work_dir/control"
    tar "${tar_args[@]}" -cf - . | gzip -n - > "$work_dir/control.tar.gz"
  )
  (
    cd "$work_dir/data"
    tar "${tar_args[@]}" -cf - . | gzip -n - > "$work_dir/data.tar.gz"
  )
  printf '2.0\n' > "$work_dir/debian-binary"
  (
    cd "$work_dir"
    tar "${tar_args[@]}" -cf - ./debian-binary ./data.tar.gz ./control.tar.gz | gzip -n - > "$output_file"
  )
  echo "$output_file"
}

build_oxidns() {
  local work_dir="$tmp_root/oxidns"
  local data_dir="$work_dir/data"
  local control_dir="$work_dir/control"

  mkdir -p "$data_dir/usr/bin" \
    "$data_dir/etc/oxidns" \
    "$data_dir/etc/init.d" \
    "$data_dir/usr/libexec" \
    "$data_dir/usr/share/oxidns/webui" \
    "$control_dir"

  install -m 0755 "$binary" "$data_dir/usr/bin/oxidns"
  install -m 0644 "$package_dir/files/etc/oxidns/config.yaml" "$data_dir/etc/oxidns/config.yaml"
  install -m 0755 "$package_dir/files/etc/init.d/oxidns" "$data_dir/etc/init.d/oxidns"
  install -m 0755 "$package_dir/files/usr/libexec/oxidns-openwrt" "$data_dir/usr/libexec/oxidns-openwrt"
  cp -R "$webui_dir"/. "$data_dir/usr/share/oxidns/webui/"

  cat > "$control_dir/control" <<EOF
Package: oxidns
Version: $version
Architecture: $arch
Maintainer: Sven Shi <isvenshi@gmail.com>
Installed-Size: $(installed_size_kb "$data_dir")
Depends: ca-bundle
Section: net
Priority: optional
Description: OxiDNS DNS policy orchestration engine
 OxiDNS is a high-performance DNS policy orchestration engine with UDP, TCP,
 DoT, DoQ, DoH, caching, fallback chains, rule providers, management APIs, and
 a standalone WebUI.
EOF

  cat > "$control_dir/conffiles" <<'EOF'
/etc/oxidns/config.yaml
/etc/oxidns/initial_password
EOF

  cat > "$control_dir/postinst" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0
/usr/libexec/oxidns-openwrt init-config || true
/etc/init.d/oxidns enable || true
/etc/init.d/oxidns start || true
exit 0
EOF
  chmod 0755 "$control_dir/postinst"

  cat > "$control_dir/prerm" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0
case "$1" in
	remove)
		/etc/init.d/oxidns stop || true
		/etc/init.d/oxidns disable || true
		;;
esac
exit 0
EOF
  chmod 0755 "$control_dir/prerm"

  write_archive "oxidns" "$arch" "$work_dir"
}

build_luci_app() {
  local work_dir="$tmp_root/luci-app-oxidns"
  local data_dir="$work_dir/data"
  local control_dir="$work_dir/control"

  mkdir -p "$data_dir/usr/share/luci/menu.d" \
    "$data_dir/usr/share/rpcd/acl.d" \
    "$data_dir/www/luci-static/resources/view/oxidns" \
    "$control_dir"

  install -m 0644 "$package_dir/files/usr/share/luci/menu.d/luci-app-oxidns.json" \
    "$data_dir/usr/share/luci/menu.d/luci-app-oxidns.json"
  install -m 0644 "$package_dir/files/usr/share/rpcd/acl.d/luci-app-oxidns.json" \
    "$data_dir/usr/share/rpcd/acl.d/luci-app-oxidns.json"
  install -m 0644 "$package_dir/files/www/luci-static/resources/view/oxidns/status.js" \
    "$data_dir/www/luci-static/resources/view/oxidns/status.js"

  cat > "$control_dir/control" <<EOF
Package: luci-app-oxidns
Version: $version
Architecture: all
Maintainer: Sven Shi <isvenshi@gmail.com>
Installed-Size: $(installed_size_kb "$data_dir")
Depends: oxidns, luci-base, rpcd
Section: luci
Priority: optional
Description: LuCI support for OxiDNS
 Lightweight LuCI entry for OxiDNS. It shows service status, controls
 start/stop/restart, displays or resets the generated API password, and links
 to the bundled OxiDNS WebUI.
EOF

  write_archive "luci-app-oxidns" "all" "$work_dir"
}

build_oxidns
build_luci_app
