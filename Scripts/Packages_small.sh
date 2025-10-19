#!/bin/bash
# ======================================================
# Scripts/Packages_small.sh —— SMALL 固件专用（≤128MB 闪存）
# 约定：本脚本在 wrt/ 根目录执行（WRT-CORE 已 cd ./wrt/ 再调用）
# 目标：
#   1) 只引入你要的极简外源包：momo(来自 nikkinikki-org) + nikki (+ gecoosac + netspeedtest)
#   2) 提供 sing-box 兜底源码（即使 SMALL 默认 homeproxy=n）
# ======================================================

set -euo pipefail

WRT_ROOT="$(pwd)"
PKG_DIR="$WRT_ROOT/package"

echo "=============================="
echo " SMALL Packages_small.sh started..."
echo "  - WRT_ROOT : $WRT_ROOT"
echo "  - PKG_DIR  : $PKG_DIR"
echo "=============================="

# 带 Token 的 https（规避少量环境对匿名 https 的限制）
if [[ -n "${GITHUB_ACTOR:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
  git config --global url."https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

# 稀疏克隆：只取子目录
git_sparse_pick() {
  # 用法：git_sparse_pick <dst_dir> <branch> <repo_url> <paths...>
  local dst="$1" br="$2" url="$3"; shift 3
  rm -rf "$dst" "_tmp_sparse.$$"
  git clone --depth=1 -b "$br" --single-branch --filter=blob:none --sparse "$url" "_tmp_sparse.$$"
  pushd "_tmp_sparse.$$" >/dev/null
  git sparse-checkout set "$@"
  mkdir -p "$dst"
  for p in "$@"; do
    if [[ -d "$p" ]]; then
      cp -a "$p"/. "$dst/"
    fi
  done
  popd >/dev/null
  rm -rf "_tmp_sparse.$$"
}

# 1) sing-box 兜底：仅当源码树中缺失时补齐到 $PKG_DIR/sing-box
if ! find "$WRT_ROOT/feeds" "$PKG_DIR" -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . ; then
  echo ">> Adding lightweight sing-box (sbwml version) into $PKG_DIR/sing-box"
  rm -rf "$PKG_DIR/sing-box"
  git clone --depth=1 https://github.com/sbwml/sing-box "$PKG_DIR/sing-box"
else
  echo ">> sing-box already present in feeds/package."
fi

# 2) 轻量插件集合（全部落在 $PKG_DIR 下）
echo ">> Cloning small set packages into $PKG_DIR"
rm -rf "$PKG_DIR/homeproxy" "$PKG_DIR/nikki" "$PKG_DIR/luci-app-momo" "$PKG_DIR/gecoosac" "$PKG_DIR/netspeedtest" 2>/dev/null || true

# homeproxy 仅提供源码（SMALL 的 Config/Settings 默认是 n）
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy            "$PKG_DIR/homeproxy"
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki   "$PKG_DIR/nikki"

# momo（正确来源）：nikkinikki-org/OpenWrt-momo/luci-app-momo
git_sparse_pick "$PKG_DIR/luci-app-momo" "main" "https://github.com/nikkinikki-org/OpenWrt-momo" "luci-app-momo"

git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac       "$PKG_DIR/gecoosac"
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest "$PKG_DIR/netspeedtest"

# 3) 主题：argon（体积小）
if [[ ! -d "$PKG_DIR/luci-theme-argon" ]]; then
  git clone --depth=1 -b openwrt-24.10 https://github.com/sbwml/luci-theme-argon "$PKG_DIR/luci-theme-argon"
  git clone --depth=1 https://github.com/sbwml/luci-app-argon-config            "$PKG_DIR/luci-app-argon-config"
fi

# 4) 移除 SMALL 不需要的大包（避免误选）
echo ">> Removing heavy packages not for SMALL"
rm -rf "$PKG_DIR"/{docker,containerd,dockerman,podman,lucky,OpenClash,openwrt-passwall,openwrt-passwall2,qbittorrent,gost,nginx,adguardhome} 2>/dev/null || true
rm -rf "$WRT_ROOT/feeds/packages/net"/{docker*,podman*,openclash*,qbittorrent*,v2ray*,xray*,gost*,adguardhome*,sing-box} 2>/dev/null || true
rm -rf "$WRT_ROOT/feeds/luci/applications"/luci-app-{dockerman,podman,openclash,passwall*,qbittorrent,gost,adguardhome,lucky} 2>/dev/null || true

# 5) 清理 .git，减小体积
find "$PKG_DIR" -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true

echo ">> SMALL package set prepared successfully!"
echo ">> Installed lightweight apps:"
ls -1 "$PKG_DIR" | grep -E "homeproxy|nikki|luci-app-momo|gecoosac|netspeedtest|sing-box" || echo "⚠️ none"
