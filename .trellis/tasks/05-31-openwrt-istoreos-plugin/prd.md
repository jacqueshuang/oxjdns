# 将 OxiDNS 打包为 OpenWrt / iStoreOS 可安装插件

## 目标

让 OxiDNS 能以 OpenWrt / iStoreOS 原生软件包的形式安装和运行。用户应该可以通过 `opkg` 安装，系统通过 OpenWrt 的 `procd` 服务机制托管 OxiDNS，并保留现有 DNS 服务、管理 API 和 WebUI 能力。

## 已知信息

- OxiDNS 是 Rust 编写的 DNS 服务，已经支持 UDP、TCP、DoT、DoQ、DoH、插件流水线、管理 API 和静态 WebUI。
- 当前仓库已经有 Debian 打包配置、systemd 服务文件和 Docker runtime，但还没有 OpenWrt 的包定义、`procd` 启动脚本、LuCI 插件或 `.ipk` 发布流程。
- 现有 Debian/systemd 布局是：
  - 程序：`/usr/bin/oxidns`
  - 配置：`/etc/oxidns/config.yaml`
  - 工作目录：`/var/lib/oxidns`
  - WebUI：`/usr/share/oxidns/webui`
- 当前默认配置监听：
  - 管理 API：`:9199`
  - DNS UDP/TCP：`:5335`
  - WebUI 静态目录：`./webui`
- README 的路线图里已经写了 OpenWrt 支持，目标是通过 `opkg` 一键安装并自动托管服务。

## 临时假设

- 第一阶段主要做平台打包，不改 OxiDNS 核心 DNS 请求处理逻辑。
- iStoreOS 先按标准 OpenWrt `.ipk` / `opkg` 兼容来做。
- 首批直接安装目标优先支持 `x86_64` 和 iStoreOS 常见的 `aarch64_cortex-a53`，因为 iStoreOS 软件源也按 OpenWrt package architecture 分发 arm64 包。
- OxiDNS 已有自己的 WebUI，第一阶段可以先通过 OxiDNS 管理 API 提供 WebUI，不一定马上做完整 LuCI 管理界面。

## 当前待确认问题

- 是否还需要纳入额外的 MVP 边界项；若无，进入实现阶段。

## 需求（持续更新）

- 新增 OpenWrt 原生包定义。
- 包内包含 OxiDNS 程序、默认配置、服务脚本，以及需要时的 WebUI 静态文件。
- 发布流程需要产出可直接安装的 `.ipk`。
- 新增轻量 LuCI / iStore 入口，让用户能从 OpenWrt/iStoreOS 管理界面发现并进入 OxiDNS。
- LuCI / iStore 入口显示 OxiDNS 服务状态，并提供启动、停止、重启操作。
- LuCI / iStore 入口提供跳转到 OxiDNS 自带 WebUI 的入口。
- 使用 OpenWrt `procd` 管理服务，支持开机启动、启动、停止、重启、重载。
- 安装 OxiDNS 服务包后，默认自动启用并启动 OxiDNS。
- 默认 DNS 监听端口保持 `5335`，避免与 OpenWrt/iStoreOS 常见的 `dnsmasq` 53 端口冲突。
- 首批 `.ipk` 发布目标为 OpenWrt/iStoreOS 24.10 的 `x86_64` 和 `aarch64_cortex-a53`。
- OpenWrt/iStoreOS 默认配置中，OxiDNS 管理 API 和自带 WebUI 监听 `0.0.0.0:9199`，允许局域网直接访问。
- LuCI / iStore 入口跳转到 OxiDNS 自带 WebUI，目标地址为路由器局域网地址的 `9199` 端口。
- OpenWrt/iStoreOS 默认启用管理 API Basic Auth。
- 安装时自动生成随机管理密码，默认用户名为 `admin`。
- LuCI / iStore 轻量入口提供查看初始密码或重置密码的入口。
- 第一版 `.ipk` 只通过 GitHub Release 分发，不生成 opkg 软件源索引，不尝试 iStore 官方仓库上架。
- 配置文件需要作为 OpenWrt `conffiles` 处理，升级时尽量保留用户配置。
- 文档需要说明如何在 OpenWrt / iStoreOS 上构建、安装、启动和卸载。
- 不影响现有 Linux、macOS、Windows、Debian、Docker 发布产物。

## 验收标准（持续更新）

- [ ] 仓库中存在 OpenWrt 包定义目录。
- [ ] 包可以安装 OxiDNS 二进制、默认配置、服务脚本和必要的 WebUI 文件。
- [ ] 配置文件被声明为持久配置文件，升级时不会无声覆盖用户配置。
- [ ] `/etc/init.d/oxidns enable/start/stop/restart/reload` 可用于服务管理。
- [ ] 安装服务包后默认启用并启动 OxiDNS。
- [ ] 默认配置不会占用系统 DNS 常用的 53 端口。
- [ ] 文档包含 OpenWrt SDK 构建方式和 `opkg install` 安装方式。
- [ ] 发布流程能产出 OpenWrt/iStoreOS 24.10 `x86_64` 和 `aarch64_cortex-a53` 的 `.ipk`。
- [ ] OpenWrt / iStoreOS 管理界面中有 OxiDNS 入口。
- [ ] LuCI / iStore 入口能显示服务状态。
- [ ] LuCI / iStore 入口能启动、停止、重启 OxiDNS。
- [ ] LuCI / iStore 入口能跳转到 OxiDNS 自带 WebUI。
- [ ] 局域网设备可以访问 OxiDNS WebUI/API。
- [ ] WebUI/API 默认启用 Basic Auth。
- [ ] 安装时生成随机管理密码，不使用固定默认密码。
- [ ] LuCI / iStore 入口能查看初始密码或重置密码。
- [ ] GitHub Release 中包含 OpenWrt/iStoreOS `.ipk` 产物。

## 完成定义

- 如果改到 Rust 代码，需要保持格式化、lint 和测试通过。
- 如果只改打包和文档，也需要做静态检查、脚本语法检查和尽可能的包结构校验。
- 中文 README 和英文 README 中的安装说明需要保持一致。
- 需要考虑升级、卸载、保留配置、服务自启动这些运维细节。

## 调研记录

- `research/openwrt-istoreos-packaging.md`：OpenWrt 包结构、`procd` 服务脚本、Rust/Cargo 打包方式、iStore/iStoreOS 兼容性调研。

## 技术说明

- OpenWrt 包建议放在 `packaging/openwrt/oxidns/` 之类的位置。
- LuCI 入口建议作为独立包处理，例如 `luci-app-oxidns`，避免把服务包和 Web 管理入口强绑在一起。
- OpenWrt 服务脚本建议安装到 `/etc/init.d/oxidns`，并使用 `USE_PROCD=1`。
- OpenWrt 包可以复用现有布局：`/usr/bin/oxidns`、`/etc/oxidns/config.yaml`、`/var/lib/oxidns`、`/usr/share/oxidns/webui`。
- OpenWrt Rust 包可以参考官方 packages feed 里的 `lang/rust/rust-package.mk`，用 `cargo install --locked` 构建。
- 如果要做到普通用户“直接安装”，还需要 release 或 CI 产出 `.ipk`，只提供源码 feed 还不够。

## 决策记录

### 选择完整插件体验

- 背景：用户需要 OxiDNS 在 OpenWrt / iStoreOS 上“直接安装”，并且更像系统里的插件，而不是只有命令行服务。
- 决定：选择方案 C，即标准 OpenWrt 服务包 + release `.ipk` + LuCI / iStore 管理入口。
- 影响：交付范围会比单纯 `.ipk` 更大，需要同时维护后端服务包和 LuCI 入口包；但最终体验更贴近 iStoreOS 用户预期。

### LuCI / iStore 入口采用轻量模式

- 背景：OxiDNS 已经有自带 WebUI，重复在 LuCI 中实现完整管理界面会增加维护成本。
- 决定：LuCI / iStore 入口只做服务状态、启动、停止、重启，以及跳转到 OxiDNS 自带 WebUI。
- 影响：第一版能快速提供“看得见、能控制、能进入管理”的插件体验；高级配置继续在 OxiDNS 自带 WebUI 中完成。

### 安装后自动启用并启动

- 背景：用户希望插件能在 OpenWrt / iStoreOS 上直接安装使用。
- 决定：安装 OxiDNS 服务包后默认执行服务启用和启动。
- 影响：安装体验更接近“一装即用”；默认 DNS 端口继续使用 `5335`，避免影响系统已有 `dnsmasq`。

### 首批发布目标

- 背景：iStoreOS 常见直接安装目标主要是 x86_64 和 arm64，范围过大会拖慢第一版落地；arm64 第一版按 iStoreOS 常见的 `aarch64_cortex-a53` 包架构处理。
- 决定：首批 `.ipk` 只覆盖 OpenWrt/iStoreOS 24.10 的 `x86_64` 和 `aarch64_cortex-a53`。
- 影响：release 矩阵更可控；OpenWrt 23.05、armv7、mips/mipsel 等后续再扩展。

### WebUI/API 默认开放给局域网

- 背景：用户希望电脑或手机能直接访问 OxiDNS 自带 WebUI，插件安装后更容易使用。
- 决定：OpenWrt/iStoreOS 默认配置中，管理 API 和 WebUI 监听 `0.0.0.0:9199`。
- 影响：使用体验更直接；因为管理端口暴露给局域网，必须明确默认认证策略。

### 安装时生成随机管理密码

- 背景：OxiDNS 管理 API 和 WebUI 默认开放给局域网，不能使用无认证或固定弱密码。
- 决定：OpenWrt/iStoreOS 安装时自动生成随机密码，用户名默认 `admin`，并写入 OxiDNS 配置。
- 影响：初始安装更安全；LuCI / iStore 轻量入口需要提供查看初始密码或重置密码的能力。

### 第一版只通过 GitHub Release 分发 `.ipk`

- 背景：用户需要直接安装，但完整 opkg 软件源索引和 iStore 官方上架会增加额外发布与审核工作。
- 决定：第一版 `.ipk` 产物随 GitHub Release 发布，用户下载后用 `opkg install ./xxx.ipk` 安装。
- 影响：交付速度更快；`Packages.gz` 软件源索引、签名和 iStore 官方上架后续再做。

## 暂不包含

- 暂不修改 DNS 核心请求路径。
- 暂不重做现有 WebUI。
- 除非进一步确认，否则暂不在 LuCI 中重做完整 OxiDNS 管理界面。
- 第一版暂不生成 opkg 软件源索引。
- 第一版暂不处理 iStore 官方仓库上架流程。
