include $(TOPDIR)/rules.mk

PKG_NAME:=oxidns
PKG_VERSION:=1.1.4
PKG_RELEASE:=1

OXIDNS_SOURCE_URL?=https://codeload.github.com/svenshi/oxidns/tar.gz/v$(PKG_VERSION)?
OXIDNS_SOURCE_HASH?=skip
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Sven Shi <isvenshi@gmail.com>

OXIDNS_PREBUILT_BINARY?=
OXIDNS_WEBUI_DIR?=$(PKG_BUILD_DIR)/webui/out

ifeq ($(strip $(OXIDNS_PREBUILT_BINARY)),)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=$(OXIDNS_SOURCE_URL)
PKG_HASH:=$(OXIDNS_SOURCE_HASH)
PKG_BUILD_DEPENDS:=rust/host
endif

include $(INCLUDE_DIR)/package.mk

ifeq ($(strip $(OXIDNS_PREBUILT_BINARY)),)
RUST_PKG_LOCKED:=1
include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk
else
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
	$(INSTALL_DIR) $(PKG_INSTALL_DIR)/bin
	$(INSTALL_BIN) $(OXIDNS_PREBUILT_BINARY) $(PKG_INSTALL_DIR)/bin/oxidns
endef
endif

define Package/oxidns
  SECTION:=net
  CATEGORY:=Network
  TITLE:=OxiDNS DNS policy orchestration engine
  URL:=https://github.com/svenshi/oxidns
  DEPENDS:=+ca-bundle
endef

define Package/oxidns/description
  OxiDNS is a high-performance DNS policy orchestration engine with
  UDP, TCP, DoT, DoQ, DoH, caching, fallback chains, rule providers,
  management APIs, and a standalone WebUI.
endef

define Package/oxidns/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/oxidns $(1)/usr/bin/oxidns
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/oxidns $(1)/etc/init.d/oxidns
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/usr/libexec/oxidns-openwrt $(1)/usr/libexec/oxidns-openwrt
	$(INSTALL_DIR) $(1)/usr/share/oxidns
	$(INSTALL_CONF) ./files/etc/oxidns/config.yaml $(1)/usr/share/oxidns/config.default.yaml
	$(INSTALL_DIR) $(1)/usr/share/oxidns/webui
	if [ -d "$(OXIDNS_WEBUI_DIR)" ]; then \
		$(CP) $(OXIDNS_WEBUI_DIR)/* $(1)/usr/share/oxidns/webui/; \
	else \
		echo "OxiDNS WebUI assets not found at $(OXIDNS_WEBUI_DIR)" >&2; \
		exit 1; \
	fi
endef

define Package/oxidns/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/usr/libexec/oxidns-openwrt init-config || true
/etc/init.d/oxidns enable || true
/etc/init.d/oxidns start || true
exit 0
endef

define Package/oxidns/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
case "$$1" in
	remove)
		/etc/init.d/oxidns stop || true
		/etc/init.d/oxidns disable || true
		;;
esac
exit 0
endef

define Package/luci-app-oxidns
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for OxiDNS
  PKGARCH:=all
  DEPENDS:=+luci-base +rpcd +oxidns
endef

define Package/luci-app-oxidns/description
  Lightweight LuCI entry for OxiDNS. It shows service status, controls
  start/stop/restart, displays or resets the generated API password,
  and links to the bundled OxiDNS WebUI.
endef

define Package/luci-app-oxidns/install
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/usr/share/luci/menu.d/luci-app-oxidns.json $(1)/usr/share/luci/menu.d/luci-app-oxidns.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/luci-app-oxidns.json $(1)/usr/share/rpcd/acl.d/luci-app-oxidns.json
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/oxidns
	$(INSTALL_DATA) ./files/www/luci-static/resources/view/oxidns/status.js $(1)/www/luci-static/resources/view/oxidns/status.js
endef

$(eval $(call BuildPackage,oxidns))
$(eval $(call BuildPackage,luci-app-oxidns))
