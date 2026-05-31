# OpenWrt / iStoreOS packaging

This directory contains the OpenWrt source package for OxiDNS.

It defines two binary packages:

- `oxidns`: the OxiDNS daemon, default OpenWrt config, `procd` init script,
  helper script, and bundled WebUI assets.
- `luci-app-oxidns`: a lightweight LuCI entry that shows service state,
  starts/stops/restarts OxiDNS, displays or resets the generated API password,
  and opens the bundled OxiDNS WebUI.

## Release build

The GitHub release workflow builds `.ipk` packages with OpenWrt 24.10 SDKs for:

- `x86_64` via target `x86/64`
- `aarch64_cortex-a53` via target `mediatek/filogic`

The workflow packages the existing `*-unknown-linux-musl` release binaries, so
it does not rebuild Rust inside the OpenWrt SDK. The package `Makefile` still
supports source builds when `OXIDNS_PREBUILT_BINARY` is not set.

## Local SDK build

Inside an OpenWrt SDK or buildroot:

```sh
./scripts/feeds update packages luci
./scripts/feeds install rust ca-bundle luci-base rpcd
cp -R /path/to/oxidns/packaging/openwrt/oxidns package/oxidns
make menuconfig
```

Select:

- `Network -> oxidns`
- `LuCI -> Applications -> luci-app-oxidns`

For a source build, make sure `webui/out` exists in the OxiDNS source tree or
override `OXIDNS_WEBUI_DIR` when invoking `make`.

For a prebuilt-binary package build:

```sh
make package/oxidns/compile V=s \
  OXIDNS_PREBUILT_BINARY=/absolute/path/to/oxidns \
  OXIDNS_WEBUI_DIR=/absolute/path/to/webui
```

## Runtime defaults

- Config: `/etc/oxidns/config.yaml`
- Generated password: `/etc/oxidns/initial_password`
- Working directory: `/var/lib/oxidns`
- WebUI assets: `/usr/share/oxidns/webui`
- DNS listen: `:5335`
- WebUI/API listen: `0.0.0.0:9199`

The package post-install script initializes the random API password, enables the
service, and starts it on real devices. It skips service startup when
`IPKG_INSTROOT` is set during image builds.
