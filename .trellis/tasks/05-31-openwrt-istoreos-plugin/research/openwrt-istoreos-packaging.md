# OpenWrt / iStoreOS 打包调研

## 参考资料

- OpenWrt 创建软件包：https://openwrt.org/docs/guide-developer/packages
- OpenWrt 软件包策略：https://openwrt.org/docs/guide-developer/package-policies
- OpenWrt procd 服务机制：https://openwrt.org/docs/techref/procd
- OpenWrt opkg 包管理器：https://openwrt.org/docs/guide-user/additional-software/opkg
- OpenWrt packages feed：https://github.com/openwrt/packages
- OpenWrt Rust 打包辅助脚本：https://github.com/openwrt/packages/blob/master/lang/rust/rust-package.mk
- OpenWrt Rust 目标平台映射：https://github.com/openwrt/packages/blob/master/lang/rust/rust-values.mk
- iStore README：https://github.com/linkease/istore/blob/main/README.md
- iStore LuCI 包定义：https://github.com/linkease/istore/blob/main/luci/luci-app-store/Makefile
- iStoreOS 仓库：https://github.com/istoreos/istoreos

## 关键结论

- OpenWrt 源码包通常由一个包目录组成，里面有 `Makefile`，可选 `patches/`，可选 `files/`。
- `files/` 常用于放默认配置、`/etc/init.d/` 服务脚本、辅助脚本等静态文件。
- OpenWrt 最终安装包是 `.ipk`，运行中的系统通过 `opkg` 安装。
- OpenWrt 包的 `Makefile` 通常需要声明：
  - `PKG_NAME`
  - `PKG_VERSION`
  - `PKG_RELEASE`
  - license 信息
  - maintainer
  - 分类、标题、描述
  - 运行依赖 `DEPENDS`
  - 持久配置文件 `conffiles`
  - `Package/<name>/install`
- OpenWrt 提供 `INSTALL_DIR`、`INSTALL_BIN`、`INSTALL_DATA`、`INSTALL_CONF` 等宏，用于安装目录、可执行文件、普通数据文件和配置文件。
- 服务程序应该安装 `/etc/init.d/<name>` 脚本。现代 OpenWrt 推荐使用 `procd`：
  - `USE_PROCD=1`
  - `procd_open_instance`
  - `procd_set_param command ...`
  - `procd_set_param respawn`
  - `procd_set_param stdout 1`
  - `procd_set_param stderr 1`
  - `procd_add_reload_trigger`
- OpenWrt packages feed 已经有 Rust 打包辅助文件 `lang/rust/rust-package.mk`，核心思路是用 `cargo install --locked --root $(PKG_INSTALL_DIR) --path ...` 构建并安装。
- OpenWrt Rust 辅助脚本会把 OpenWrt 的目标平台、交叉编译器、链接器等信息映射到 Cargo 环境变量。
- OpenWrt 当前 Rust 辅助脚本支持一批架构，包括 `aarch64`、`arm`、`i386`、`mips`、`mips64`、`mipsel`、`riscv64`、`x86_64`。
- iStore 自称是标准 OpenWrt 软件中心实现，是 iStoreOS 的一部分。
- iStore README 里明确说官方软件仓库支持 `x86_64` 和 `arm64`。
- iStore 当前公开软件源包含 `aarch64_cortex-a53` 目录，因此第一版 arm64 `.ipk` 应优先按该 OpenWrt package architecture 产出。
- iStore 也提醒：OpenWrt 版本很多，不同平台依赖可能不同，所以插件不一定能在所有系统上安装。
- iStore 的自身 LuCI 插件是一个独立 LuCI 应用，依赖 `curl`、`opkg`、LuCI 相关库等。这说明“后端服务包”和“LuCI/iStore 前端入口”可以拆成两个包。

## 对 OxiDNS 的影响

- 最基础、最稳妥的交付物应该是标准 OpenWrt 包定义，让 OpenWrt SDK 或 buildroot 可以构建 `.ipk`。
- OxiDNS 服务包建议包含：
  - `/usr/bin/oxidns`
  - `/etc/oxidns/config.yaml`
  - `/etc/init.d/oxidns`
  - `/var/lib/oxidns`
  - 可选 `/usr/share/oxidns/webui`
- iStoreOS 首先按标准 OpenWrt / `opkg` 兼容来处理。
- 如果要做 iStore 里“看起来像插件”的体验，可以后续再加一个独立的 `luci-app-oxidns` 包。
- 因为 OxiDNS 已经有自己的 WebUI，第一版 LuCI 集成可以很轻，只做菜单入口、服务状态和跳转，不必重写完整管理界面。
- Rust 从源码在 OpenWrt SDK 里编译更符合 ABI，但会比较重；如果目标是普通用户直接安装，就需要 CI 或 release 产出 `.ipk`。

## 可选方案

### 方案 A：只做 OpenWrt package feed

新增 `packaging/openwrt/oxidns/`，包含 OpenWrt 包 `Makefile`、`files/oxidns.init`、默认配置和构建说明。用户或固件作者用 OpenWrt SDK 自己构建 `.ipk`。

优点：
- 最快、最稳。
- 符合 OpenWrt 官方包开发方式。
- 后续容易提交到第三方 feed 或官方 packages feed。

缺点：
- 普通用户还不能直接下载 `.ipk` 安装。
- 离“直接安装”还差一步发布流程。

### 方案 B：package feed + 发布 `.ipk`

在方案 A 的基础上，增加 release/CI 流程，为选定 OpenWrt/iStoreOS 目标产出 `.ipk`，例如 `x86_64` 和 `aarch64_cortex-a53`。

优点：
- 更符合“直接安装”的目标。
- 用户可以下载 `.ipk` 后 `opkg install`。
- 仍然保留标准 package feed，方便开发者和固件作者集成。

缺点：
- 需要维护 OpenWrt SDK 构建矩阵。
- 需要处理包仓库、架构、依赖和 release 产物命名。

### 方案 C：服务包 + LuCI/iStore 入口

在方案 B 的基础上，再增加一个 `luci-app-oxidns` 包，提供 OpenWrt/iStoreOS Web 管理入口，例如菜单、服务状态、跳转到 OxiDNS WebUI。

优点：
- 对 iStoreOS 用户最友好，体验最像“插件”。
- 不需要用户记端口或命令。

缺点：
- 范围更大，需要遵循 LuCI 包结构。
- 如果做完整管理界面，会和 OxiDNS 现有 WebUI 重复。
- 推荐先做轻量入口，而不是重写管理界面。

## 最终选择

用户确认选择方案 C：标准 OpenWrt 服务包 + release 产出 `.ipk` + 轻量 `luci-app-oxidns` 入口。

落地时控制 LuCI 范围：
- 只做服务状态、启动、停止、重启、查看/重置密码和跳转 WebUI。
- 不在 LuCI 中重做完整 OxiDNS 管理界面。
- 第一版 `.ipk` 只通过 GitHub Release 分发，不生成 opkg 软件源索引，也不处理 iStore 官方仓库上架。
