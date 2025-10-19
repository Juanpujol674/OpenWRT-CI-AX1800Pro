#!/bin/bash
# ======================================================
#  Scripts/Packages_small.sh
#  轻量版：为 SMALL 机型（≤128MB 闪存）设计
#  在 wrt 根目录执行（WRT-CORE.yml 已调整为 cd ./wrt/ 后调用）
# ======================================================

set -e
WRT_ROOT="${PWD}"
PKG_DIR="$WRT_ROOT/package"

echo "=============================="
echo " SMALL Packages_small.sh started..."
echo "  - WRT_ROOT : $WRT_ROOT"
echo "  - PKG_DIR  : $PKG_DIR"
echo "=============================="

mkdir -p "$PKG_DIR"

# -------------------------------
# 1) 兜底提供 sing-box（优先：feeds；否则从 ImmortalWrt/packages sparse 取 net/sing-box）
# -------------------------------
if ! find "$WRT_ROOT/feeds" -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . && [ ! -d "$PKG_DIR/sing-box" ]; then
  echo ">> Adding sing-box (sparse from immortalwrt/packages)"
  TMP_DIR="$(mktemp -d)"
  git clone --depth=1 -b master --filter=blob:none --sparse https://github.com/immortalwrt/packages "$TMP_DIR"
  ( cd "$TMP_DIR" && git sparse-checkout set net/sing-box )
  # 移入本地 package/
  cp -a "$TMP_DIR/net/sing-box" "$PKG_DIR/sing-box"
  rm -rf "$TMP_DIR"
fi

# -------------------------------
# 2) 轻量插件集合（homeproxy/nikki/momo/…）
#    注：momo 取自 nikkinikki-org/OpenWrt-momo 的 luci-app-momo 子目录
# -------------------------------
# homeproxy（如 SMALL 配置里是 n，不会安装，仅存在不影响）
if [ ! -d "$PKG_DIR/homeproxy" ]; then
  git clone --depth=1 https://github.com/VIKINGYFY/homeproxy "$PKG_DIR/homeproxy"
fi

# nikki
if [ ! -d "$PKG_DIR/nikki" ]; then
  git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki "$PKG_DIR/nikki"
fi

# momo（只拉 luci-app-momo 子目录）
if [ ! -d "$PKG_DIR/luci-app-momo" ]; then
  TMP_DIR="$(mktemp -d)"
  git clone --depth=1 --filter=blob:none --sparse https://github.com/nikkinikki-org/OpenWrt-momo "$TMP_DIR"
  ( cd "$TMP_DIR" && git sparse-checkout set luci-app-momo )
  cp -a "$TMP_DIR/luci-app-momo" "$PKG_DIR/luci-app-momo"
  rm -rf "$TMP_DIR"
fi

# 其它轻插件（按需）
[ -d "$PKG_DIR/gecoosac" ] || git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac "$PKG_DIR/gecoosac"
[ -d "$PKG_DIR/netspeedtest" ] || git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest "$PKG_DIR/netspeedtest"

# -------------------------------
# 3) 仅保留轻主题 argon（主题与配置）
# -------------------------------
rm -rf "$WRT_ROOT/feeds/luci/themes/luci-theme-"*
[ -d "$PKG_DIR/luci-theme-argon" ] || git clone --depth=1 -b openwrt-24.10 https://github.com/sbwml/luci-theme-argon "$PKG_DIR/luci-theme-argon"
[ -d "$PKG_DIR/luci-app-argon-config" ] || git clone --depth=1 https://github.com/sbwml/luci-app-argon-config "$PKG_DIR/luci-app-argon-config"

# -------------------------------
# 4) 清理不适合 SMALL 的大型包（安全起见）
# -------------------------------
echo ">> Removing heavy packages (docker/podman/lucky/qbittorrent/gost/nginx/adguardhome …)"
rm -rf "$PKG_DIR"/{docker,containerd,dockerman,podman,lucky,openclash,passwall*,qbittorrent,gost,nginx,adguardhome}
rm -rf "$WRT_ROOT/feeds/packages/net"/{docker*,podman*,openclash*,qbittorrent*,v2ray*,xray*,gost*,adguardhome*}
rm -rf "$WRT_ROOT/feeds/luci/applications"/luci-app-{dockerman,podman,openclash,passwall*,qbittorrent,gost,adguardhome,lucky}

# -------------------------------
# 5) 清理冗余 .git 目录
# -------------------------------
find "$WRT_ROOT/feeds" -type d -name ".git" -prune -exec rm -rf {} +
find "$PKG_DIR" -type d -name ".git" -prune -exec rm -rf {} +

# -------------------------------
# ✅ 完成
# -------------------------------
echo ">> SMALL package set prepared successfully!"
echo ">> Installed lightweight apps:"
ls -1 "$PKG_DIR" | grep -E "homeproxy|nikki|luci-app-momo|gecoosac|netspeedtest|sing-box" || echo "⚠️ No small packages detected!"
