#!/bin/bash
# ======================================================
#  Scripts/Packages_small.sh
#  轻量版：为 SMALL 机型（≤128MB 闪存）设计
#  ✅ 可从 wrt/ 或 wrt/package/ 两个位置调用，自动适配
# ======================================================

set -e

# --- 计算 wrt 根目录与包目录 ---
if [ -d "./scripts" ] && [ -d "./package" ]; then
  # 当前在 wrt/
  WRT_ROOT="$PWD"
  PKG_DIR="$WRT_ROOT/package"
elif [ -d "../scripts" ] && [ -d "../package" ]; then
  # 当前在 wrt/package/
  WRT_ROOT="$(cd .. && pwd)"
  PKG_DIR="$PWD"
else
  echo "❌ 无法定位 wrt 根目录，请在 wrt/ 或 wrt/package/ 下调用本脚本"
  exit 1
fi

echo "=============================="
echo " SMALL Packages.sh started..."
echo "  - WRT_ROOT : $WRT_ROOT"
echo "  - PKG_DIR  : $PKG_DIR"
echo "=============================="

# --- 一个小工具：安全 clone 到指定目录 ---
safe_clone() {
  local repo_url="$1" dst_dir="$2" branch="$3"
  [ -n "$dst_dir" ] || { echo "safe_clone 参数错误：缺少 dst_dir"; exit 1; }
  rm -rf "$dst_dir"
  if [ -n "$branch" ]; then
    git clone --depth=1 -b "$branch" "$repo_url" "$dst_dir"
  else
    git clone --depth=1 "$repo_url" "$dst_dir"
  fi
}

# -------------------------------
# 1️⃣ 提供 sing-box 包（homeproxy 依赖保护）
# -------------------------------
if ! find "$WRT_ROOT/feeds" -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . && \
   [ ! -d "$PKG_DIR/sing-box" ]; then
  echo ">> Adding lightweight sing-box (sbwml version)"
  rm -rf "$WRT_ROOT/package"/*/sing-box "$WRT_ROOT/feeds"/*/sing-box || true
  safe_clone "https://github.com/sbwml/sing-box.git" "$PKG_DIR/sing-box"
fi

# -------------------------------
# 2️⃣ 轻量插件集合
# -------------------------------
# 你要的：homeproxy（供依赖检查）、nikki、momo、gecoosac、netspeedtest
safe_clone "https://github.com/VIKINGYFY/homeproxy.git"                "$PKG_DIR/homeproxy"
safe_clone "https://github.com/nikkinikki-org/OpenWrt-nikki.git"      "$PKG_DIR/nikki"
safe_clone "https://github.com/sirpdboy/luci-app-momo.git"            "$PKG_DIR/momo"
safe_clone "https://github.com/lwb1978/openwrt-gecoosac.git"          "$PKG_DIR/gecoosac"
safe_clone "https://github.com/sirpdboy/luci-app-netspeedtest.git"    "$PKG_DIR/netspeedtest" "js"

# -------------------------------
# 3️⃣ LuCI 基础保障（必须在 wrt 根下执行）
# -------------------------------
echo ">> Update & install minimal luci feeds"
( cd "$WRT_ROOT" && \
  ./scripts/feeds update luci && \
  ./scripts/feeds install -a -p luci && \
  ./scripts/feeds install luci-base luci-compat luci-lib-base luci-lib-ipkg luci-lua-runtime )

# -------------------------------
# 4️⃣ 清理不适合 SMALL 的大型包
# -------------------------------
echo ">> Removing heavy packages (docker, lucky, qbittorrent, etc)"
rm -rf "$PKG_DIR"/{docker,containerd,dockerman,podman,lucky,openclash,passwall*,qbittorrent,gost,nginx,adguardhome}
rm -rf "$WRT_ROOT"/feeds/packages/net/{docker*,podman*,openclash*,qbittorrent*,v2ray*,xray*,gost*,adguardhome*,sing-box}
rm -rf "$WRT_ROOT"/feeds/luci/applications/luci-app-{dockerman,podman,openclash,passwall*,qbittorrent,gost,adguardhome,lucky}

# -------------------------------
# 5️⃣ 仅保留轻主题 argon
# -------------------------------
echo ">> Use minimal theme: luci-theme-argon"
rm -rf "$WRT_ROOT"/feeds/luci/themes/luci-theme-*
safe_clone "https://github.com/sbwml/luci-theme-argon.git"       "$PKG_DIR/luci-theme-argon" "openwrt-24.10"
safe_clone "https://github.com/sbwml/luci-app-argon-config.git"  "$PKG_DIR/luci-app-argon-config"

# -------------------------------
# 6️⃣ 冗余 .git 清理
# -------------------------------
find "$WRT_ROOT/feeds" -type d -name ".git" -exec rm -rf {} + || true
find "$WRT_ROOT/package" -type d -name ".git" -exec rm -rf {} + || true

# -------------------------------
# ✅ 构建结果检查
# -------------------------------
echo ">> SMALL package set prepared successfully!"
echo ">> Installed lightweight apps:"
ls -1 "$PKG_DIR" | grep -E "homeproxy|nikki|momo|gecoosac|netspeedtest|sing-box" || echo "⚠️ No small packages detected!"
