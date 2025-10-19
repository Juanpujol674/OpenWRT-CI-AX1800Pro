#!/bin/bash
# ======================================================
#  Scripts/Packages.sh
#  大内存/常规机型：外源包整合
#  在 wrt 根目录执行（WRT-CORE.yml 已调整为 cd ./wrt/ 后调用）
# ======================================================

set -e
WRT_ROOT="${PWD}"
PKG_DIR="$WRT_ROOT/package"

echo "=============================="
echo " Standard Packages.sh started..."
echo "  - WRT_ROOT : $WRT_ROOT"
echo "  - PKG_DIR  : $PKG_DIR"
echo "=============================="

mkdir -p "$PKG_DIR"

# 小工具：统一拉仓（可带子目录）
clone_if_missing() {
  local url="$1"
  local dest="$2"
  if [ ! -d "$dest" ]; then
    git clone --depth=1 "$url" "$dest"
  fi
}

# sparse 拉取某子目录
sparse_pull_dir() {
  local url="$1" ; local subdir="$2" ; local dest="$3"
  [ -d "$dest" ] && return 0
  local tmp="$(mktemp -d)"
  git clone --depth=1 --filter=blob:none --sparse "$url" "$tmp"
  ( cd "$tmp" && git sparse-checkout set "$subdir" )
  mkdir -p "$(dirname "$dest")"
  cp -a "$tmp/$subdir" "$dest"
  rm -rf "$tmp"
}

# -----------------------------------
# 1) sing-box 兜底（优先 feeds；否则 net/sing-box from immortalwrt/packages）
# -----------------------------------
if ! find "$WRT_ROOT/feeds" -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . && [ ! -d "$PKG_DIR/sing-box" ]; then
  echo ">> Adding sing-box (sparse from immortalwrt/packages)"
  sparse_pull_dir "https://github.com/immortalwrt/packages" "net/sing-box" "$PKG_DIR/sing-box"
fi

# -----------------------------------
# 2) 你的外源包合集（保留原有 + 补上 momo）
# -----------------------------------
clone_if_missing "https://github.com/sirpdboy/luci-theme-kucat"        "$PKG_DIR/luci-theme-kucat"
clone_if_missing "https://github.com/VIKINGYFY/homeproxy"              "$PKG_DIR/homeproxy"
clone_if_missing "https://github.com/nikkinikki-org/OpenWrt-nikki"     "$PKG_DIR/nikki"
clone_if_missing "https://github.com/vernesong/OpenClash"              "$PKG_DIR/OpenClash"
clone_if_missing "https://github.com/xiaorouji/openwrt-passwall"       "$PKG_DIR/openwrt-passwall"
clone_if_missing "https://github.com/xiaorouji/openwrt-passwall2"      "$PKG_DIR/openwrt-passwall2"
clone_if_missing "https://github.com/asvow/luci-app-tailscale"         "$PKG_DIR/luci-app-tailscale"
clone_if_missing "https://github.com/sirpdboy/luci-app-ddns-go"        "$PKG_DIR/luci-app-ddns-go"
clone_if_missing "https://github.com/lisaac/luci-app-diskman"          "$PKG_DIR/luci-app-diskman"
clone_if_missing "https://github.com/EasyTier/luci-app-easytier"       "$PKG_DIR/luci-app-easytier"
clone_if_missing "https://github.com/rockjake/luci-app-fancontrol"     "$PKG_DIR/luci-app-fancontrol"
clone_if_missing "https://github.com/lwb1978/openwrt-gecoosac"         "$PKG_DIR/openwrt-gecoosac"
clone_if_missing "https://github.com/sbwml/luci-app-mosdns"            "$PKG_DIR/luci-app-mosdns"
clone_if_missing "https://github.com/sirpdboy/luci-app-netspeedtest"   "$PKG_DIR/luci-app-netspeedtest"
clone_if_missing "https://github.com/sbwml/luci-app-openlist2"         "$PKG_DIR/luci-app-openlist2"
clone_if_missing "https://github.com/sirpdboy/luci-app-partexp"        "$PKG_DIR/luci-app-partexp"
clone_if_missing "https://github.com/sbwml/luci-app-qbittorrent"       "$PKG_DIR/luci-app-qbittorrent"
clone_if_missing "https://github.com/FUjr/QModem"                      "$PKG_DIR/QModem"
clone_if_missing "https://github.com/VIKINGYFY/packages"               "$PKG_DIR/packages"
clone_if_missing "https://github.com/lmq8267/luci-app-vnt"             "$PKG_DIR/luci-app-vnt"

# momo：从 OpenWrt-momo 仓库的 luci-app-momo 子目录 sparse 拿
sparse_pull_dir "https://github.com/nikkinikki-org/OpenWrt-momo" "luci-app-momo" "$PKG_DIR/luci-app-momo"

# 主题 argon
clone_if_missing "https://github.com/sbwml/luci-theme-argon"           "$PKG_DIR/luci-theme-argon"
clone_if_missing "https://github.com/sbwml/luci-app-argon-config"      "$PKG_DIR/luci-app-argon-config"

# -----------------------------------
# 3) 清理 .git 目录
# -----------------------------------
find "$PKG_DIR" -type d -name ".git" -prune -exec rm -rf {} +

echo ">> Standard package set prepared successfully!"
