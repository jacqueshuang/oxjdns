# Directory Structure

> How backend code is organized in this project.

---

## OpenWrt Packaging Contract

### 1. Scope / Trigger

- Trigger: changes that add or modify OpenWrt / iStoreOS packaging, `.ipk`
  release output, `procd` service behavior, or LuCI entry points.
- Scope: `packaging/openwrt/`, `.github/workflows/release.yml`, README files,
  and docs quickstart pages.

### 2. Signatures

- Source package directory: `packaging/openwrt/oxidns/`
- OpenWrt packages produced by that directory:
  - `oxidns`
  - `luci-app-oxidns`
- Runtime commands:
  - `/etc/init.d/oxidns start|stop|restart|reload|enable|disable`
  - `/etc/init.d/oxidns show_password`
  - `/etc/init.d/oxidns reset_password`
  - `/usr/libexec/oxidns-openwrt init-config|show-password|reset-password|status|start|stop|restart`

### 3. Contracts

- Installed daemon binary: `/usr/bin/oxidns`
- Config file: `/etc/oxidns/config.yaml`
- Generated password file: `/etc/oxidns/initial_password`
- Working directory: `/var/lib/oxidns`
- WebUI assets: `/usr/share/oxidns/webui`
- Init script: `/etc/init.d/oxidns`
- LuCI menu: `/usr/share/luci/menu.d/luci-app-oxidns.json`
- LuCI ACL: `/usr/share/rpcd/acl.d/luci-app-oxidns.json`
- LuCI view: `/www/luci-static/resources/view/oxidns/status.js`
- OpenWrt release matrix defaults:
  - `x86_64` via SDK target `x86/64`
  - `aarch64_cortex-a53` via SDK target `mediatek/filogic`
- `.ipk` release artifacts are published through GitHub Release assets, not an
  opkg package index in the first version.

### 4. Validation & Error Matrix

- Missing `webui/out` or missing `OXIDNS_WEBUI_DIR` during package build ->
  fail package installation step with a clear "WebUI assets not found" error.
- Missing `api.http.auth.basic.password` in `/etc/oxidns/config.yaml` when
  resetting the password -> helper exits non-zero and prints an error.
- `IPKG_INSTROOT` is set during image builds -> post-install must skip service
  enable/start side effects.
- LuCI action helper returns invalid JSON for status -> LuCI page must surface a
  notification instead of silently claiming success.

### 5. Good/Base/Bad Cases

- Good: release CI packages existing musl binaries into SDK-generated `.ipk`
  files and includes both `oxidns` and `luci-app-oxidns` artifacts.
- Base: local SDK users can build from source when `webui/out` is present.
- Bad: OpenWrt package starts OxiDNS on port `53` by default, conflicting with
  `dnsmasq`; use `:5335` unless the user intentionally changes config.
- Bad: LuCI reimplements the full OxiDNS WebUI; keep the LuCI app lightweight
  and link to the bundled OxiDNS WebUI.

### 6. Tests Required

- Shell syntax check for init/helper scripts with `sh -n`.
- JSON parse check for LuCI menu and ACL files.
- JavaScript syntax check for LuCI view files.
- YAML parse check for the release workflow and packaged config.
- `oxidns check -c <packaged config> -d <existing temp dir>` must pass.
- Release workflow changes should be reviewed for artifact names consumed by the
  publish job.

### 7. Wrong vs Correct

#### Wrong

```sh
procd_set_param command /usr/bin/oxidns start -c /etc/oxidns/config.yaml
```

This omits the working directory, so relative WebUI or state paths may resolve
from a process-manager-dependent directory.

#### Correct

```sh
procd_set_param command /usr/bin/oxidns start -c /etc/oxidns/config.yaml -d /var/lib/oxidns
```

The service has a stable runtime base and matches the package documentation.
