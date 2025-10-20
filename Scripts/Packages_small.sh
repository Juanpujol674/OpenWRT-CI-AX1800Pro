#!/bin/bash
# ======================================================
#  Scripts/Packages_small.sh —— SMALL 机型（≤128MB 闪存）专用极简外源包
#  - 保留：luci-app-momo、nikki（你要求）
#  - 为 homeproxy 依赖准备 sing-box（兜底）
#  - 清理会污染 Kconfig 的包
#  - 末尾刷新 feeds 索引
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
echo " SMALL Packages_small.sh started..."
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
# 2️⃣ 极简插件集合（你要的 momo + nikki + 少量常用）
# -------------------------------
# momo：仓库内的 luci-app-momo 子目录
sparse_clone "https://github.com/nikkinikki-org/OpenWrt-momo" "main" "luci-app-momo" "luci-app-momo"

# nikki：保持仓库目录结构
rm -rf "$PKG_DIR/OpenWrt-nikki" 2>/dev/null || true
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki "$PKG_DIR/OpenWrt-nikki"

# 少量辅助（可按需裁剪）
git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac "$PKG_DIR/openwrt-gecoosac"
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest "$PKG_DIR/luci-app-netspeedtest"

# 主题：仅保留 argon + 配置
rm -rf "$PKG_DIR/luci-theme-argon" "$PKG_DIR/luci-app-argon-config" 2>/dev/null || true
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon "$PKG_DIR/luci-theme-argon"
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config "$PKG_DIR/luci-app-argon-config"

# -------------------------------
# 3️⃣ 再次刷新 feeds 索引（关键）
# -------------------------------
cd "$WRT_ROOT"
./scripts/feeds install -a

echo ">> SMALL package set prepared OK."
