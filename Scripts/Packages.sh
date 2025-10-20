#!/bin/bash
# ======================================================
#  Scripts/Packages.sh  —— 标准/大内存机型用
#  - 拉常用第三方包
#  - 清理会污染 Kconfig 的包
#  - 末尾刷新 feeds 索引，稳定 defconfig
# ======================================================
set -e

# --- 目录探测：允许在 wrt/ 或 wrt/package/ 下调用 ---
if [ -d "./package" ] && [ -d "./scripts" ]; then
  WRT_ROOT="$(pwd)"
elif [ -d "../package" ] && [ -d "../scripts" ]; then
  WRT_ROOT="$(cd .. && pwd)"
else
  echo "!! 请在 wrt/ 或 wrt/package/ 目录下运行本脚本"
  exit 1
fi
PKG_DIR="$WRT_ROOT/package"

echo "=============================="
echo " Standard Packages.sh started..."
echo "  - WRT_ROOT : $WRT_ROOT"
echo "  - PKG_DIR  : $PKG_DIR"
echo "=============================="

# --- helper：稀疏克隆某子目录到 package/目标名 ---
sparse_clone () {
  local repo="$1" branch="$2" subpath="$3" dest="$4"
  local tmpdir
  tmpdir="$(mktemp -d)"
  git clone --filter=blob:none --no-checkout --depth=1 -b "$branch" "$repo" "$tmpdir"
  git -C "$tmpdir" sparse-checkout init --cone
  git -C "$tmpdir" sparse-checkout set "$subpath"
  git -C "$tmpdir" checkout
  rm -rf "$PKG_DIR/$dest"
  mkdir -p "$PKG_DIR/$dest"
  cp -a "$tmpdir/$subpath/." "$PKG_DIR/$dest/"
  rm -rf "$tmpdir"
}

# -------------------------------
# 0️⃣ 清理会污染 Kconfig 的包
# -------------------------------
rm -rf "$WRT_ROOT/feeds/packages/net/dae" "$WRT_ROOT/feeds/packages/net/daed" 2>/dev/null || true
rm -rf "$WRT_ROOT/feeds/luci/applications/luci-app-v2raya" 2>/dev/null || true

# -------------------------------
# 1️⃣ sing-box 兜底（immortalwrt/packages）
# -------------------------------
if ! find "$WRT_ROOT/feeds" -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . && [ ! -d "$PKG_DIR/sing-box" ]; then
  echo ">> Adding sing-box (sparse from immortalwrt/packages)"
  sparse_clone "https://github.com/immortalwrt/packages" "master" "net/sing-box" "sing-box"
fi

# -------------------------------
# 2️⃣ 主题：argon + 配置
# -------------------------------
rm -rf "$PKG_DIR/luci-theme-argon" "$PKG_DIR/luci-app-argon-config" 2>/dev/null || true
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon "$PKG_DIR/luci-theme-argon"
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config "$PKG_DIR/luci-app-argon-config"

# -------------------------------
# 3️⃣ 你常用的第三方包（完整版）
# -------------------------------
# 主题
git clone --depth=1 https://github.com/sirpdboy/luci-theme-kucat "$PKG_DIR/luci-theme-kucat"

# 科学/代理套件（按需取舍）
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy "$PKG_DIR/homeproxy"
git clone --depth=1 https://github.com/vernesong/OpenClash "$PKG_DIR/OpenClash"             # dev 默认
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall "$PKG_DIR/openwrt-passwall"
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall2 "$PKG_DIR/openwrt-passwall2"

# 你特别要求的 momo + nikki
# momo 在 nikkinikki-org/OpenWrt-momo 仓库的 luci-app-momo 子目录
sparse_clone "https://github.com/nikkinikki-org/OpenWrt-momo" "main" "luci-app-momo" "luci-app-momo"
# nikki 仓库内既有后端也有 LuCI，保持放在 package/OpenWrt-nikki 下更稳
rm -rf "$PKG_DIR/OpenWrt-nikki" 2>/dev/null || true
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki "$PKG_DIR/OpenWrt-nikki"

# 其他 LuCI 常用
git clone --depth=1 https://github.com/asvow/luci-app-tailscale "$PKG_DIR/luci-app-tailscale"
git clone --depth=1 https://github.com/sirpdboy/luci-app-ddns-go "$PKG_DIR/luci-app-ddns-go"
git clone --depth=1 https://github.com/lisaac/luci-app-diskman "$PKG_DIR/luci-app-diskman"
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier "$PKG_DIR/luci-app-easytier"
git clone --depth=1 https://github.com/rockjake/luci-app-fancontrol "$PKG_DIR/luci-app-fancontrol"
git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac "$PKG_DIR/openwrt-gecoosac"
git clone --depth=1 -b v5 https://github.com/sbwml/luci-app-mosdns "$PKG_DIR/luci-app-mosdns"
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest "$PKG_DIR/luci-app-netspeedtest"
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 "$PKG_DIR/luci-app-openlist2"
git clone --depth=1 https://github.com/sirpdboy/luci-app-partexp "$PKG_DIR/luci-app-partexp"
git clone --depth=1 https://github.com/sbwml/luci-app-qbittorrent "$PKG_DIR/luci-app-qbittorrent"
git clone --depth=1 https://github.com/FUjr/QModem "$PKG_DIR/QModem"
git clone --depth=1 https://github.com/VIKINGYFY/packages "$PKG_DIR/packages"
git clone --depth=1 https://github.com/lmq8267/luci-app-vnt "$PKG_DIR/luci-app-vnt"

# -------------------------------
# 4️⃣ 再次刷新 feeds 索引（关键）
# -------------------------------
cd "$WRT_ROOT"
./scripts/feeds install -a

echo ">> Standard package set prepared OK."
