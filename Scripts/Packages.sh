#!/bin/bash
# ======================================================
# Scripts/Packages.sh —— 大内存/常规版
# 约定：本脚本在 wrt/package/ 目录内执行（WRT-CORE 已 cd ./wrt/package/ 再调用）
# 目标：
#   1) 保证 luci-app-homeproxy 的 sing-box 依赖一定存在（优先 sbwml 版本）
#   2) 引入外部包（含 nikkinikki-org 的 luci-app-momo）
# ======================================================

set -euo pipefail

# 保险：当前目录校验（必须在 wrt/package/）
if [[ ! -f "../scripts/feeds" || ! -d "../feeds" ]]; then
  echo "ERROR: 请在 wrt/package/ 目录内执行本脚本！(当前: $(pwd))"
  exit 1
fi

title(){ echo -e "\n==== $*"; }

# 带 Token 的 https（规避少量环境对匿名 https 的限制）
if [[ -n "${GITHUB_ACTOR:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
  git config --global url."https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

# 通用克隆函数
clone_or_reset() {
  local dst="$1" url="$2" br="${3:-}"
  rm -rf "$dst"
  if [[ -n "$br" ]]; then
    git clone --depth=1 --single-branch --branch "$br" "$url" "$dst"
  else
    git clone --depth=1 "$url" "$dst"
  fi
}

# 稀疏克隆（只取部分目录）
git_sparse_pick() {
  # 用法：git_sparse_pick <dst_dir> <branch> <repo_url> <paths...>
  local dst="$1" br="$2" url="$3"; shift 3
  rm -rf "$dst" "_tmp_sparse.$$"
  git clone --depth=1 -b "$br" --single-branch --filter=blob:none --sparse "$url" "_tmp_sparse.$$"
  pushd "_tmp_sparse.$$" >/dev/null
  git sparse-checkout set "$@"
  mkdir -p "../$dst"
  # 将选中的目录内容平铺到目标 dst 下
  for p in "$@"; do
    if [[ -d "$p" ]]; then
      cp -a "$p"/. "../$dst/"
    fi
  done
  popd >/dev/null
  rm -rf "_tmp_sparse.$$"
}

# 0) 清理可能冲突的 sing-box
title "Cleanup possibly conflicting sing-box"
rm -rf ./sing-box ../feeds/*/*/sing-box ../feeds/*/sing-box ../package/*/sing-box 2>/dev/null || true

# 1) 确保 sing-box 包存在
title "Ensure sing-box package exists"
if ! find .. -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . ; then
  echo ">> sing-box not found in feeds/package, cloning sbwml/sing-box ..."
  clone_or_reset "./sing-box" "https://github.com/sbwml/sing-box"
else
  echo ">> sing-box already present."
fi

# 2) 外部包（含 momo from nikkinikki-org/OpenWrt-momo/luci-app-momo）
title "Updating external packages"

clone_or_reset "luci-theme-kucat"             "https://github.com/sirpdboy/luci-theme-kucat" "js"
clone_or_reset "homeproxy"                     "https://github.com/VIKINGYFY/homeproxy"       "main"
clone_or_reset "OpenWrt-nikki"                 "https://github.com/nikkinikki-org/OpenWrt-nikki" "main"

# momo：只取子目录 luci-app-momo 到 package/luci-app-momo
git_sparse_pick "luci-app-momo" "main" "https://github.com/nikkinikki-org/OpenWrt-momo" "luci-app-momo"

clone_or_reset "OpenClash"                     "https://github.com/vernesong/OpenClash"      "dev"
clone_or_reset "openwrt-passwall"              "https://github.com/xiaorouji/openwrt-passwall"  "main"
clone_or_reset "openwrt-passwall2"             "https://github.com/xiaorouji/openwrt-passwall2" "main"
clone_or_reset "luci-app-tailscale"            "https://github.com/asvow/luci-app-tailscale" "main"
clone_or_reset "luci-app-ddns-go"              "https://github.com/sirpdboy/luci-app-ddns-go" "main"
clone_or_reset "luci-app-diskman"              "https://github.com/lisaac/luci-app-diskman"  "master"
clone_or_reset "luci-app-easytier"             "https://github.com/EasyTier/luci-app-easytier" "main"
clone_or_reset "luci-app-fancontrol"           "https://github.com/rockjake/luci-app-fancontrol" "main"
clone_or_reset "openwrt-gecoosac"              "https://github.com/lwb1978/openwrt-gecoosac" "main"
clone_or_reset "luci-app-mosdns"               "https://github.com/sbwml/luci-app-mosdns"    "v5"
clone_or_reset "luci-app-netspeedtest"         "https://github.com/sirpdboy/luci-app-netspeedtest" "js"
clone_or_reset "luci-app-openlist2"            "https://github.com/sbwml/luci-app-openlist2" "main"
clone_or_reset "luci-app-partexp"              "https://github.com/sirpdboy/luci-app-partexp" "main"
clone_or_reset "luci-app-qbittorrent"          "https://github.com/sbwml/luci-app-qbittorrent" "master"
clone_or_reset "QModem"                        "https://github.com/FUjr/QModem"              "main"
clone_or_reset "packages"                      "https://github.com/VIKINGYFY/packages"       "main"
clone_or_reset "luci-app-vnt"                  "https://github.com/lmq8267/luci-app-vnt"     "main"

# 3) 其它附加包（按你原来的习惯）
title "Extra packages (lucky/dae/podman/…)"
rm -rf ./lucky && git clone --depth 1 --single-branch https://github.com/sirpdboy/luci-app-lucky.git lucky

rm -rf ./dae && git clone --depth 1 https://github.com/QiuSimons/luci-app-daed dae
mkdir -p Package/libcron && wget -q -O Package/libcron/Makefile https://raw.githubusercontent.com/immortalwrt/packages/refs/heads/master/libs/libcron/Makefile

git_sparse_pick "." "main" "https://github.com/kenzok8/small-package" "daed-next" "luci-app-daed-next" "gost" "luci-app-gost" "luci-app-nginx" "luci-app-adguardhome"
git_sparse_pick "." "main" "https://github.com/kiddin9/kwrt-packages" "natter2" "luci-app-natter2" "luci-app-cloudflarespeedtest" "luci-app-caddy" "openwrt-caddy"

rm -rf ./podman && git clone --depth 1 --single-branch https://github.com/breeze303/openwrt-podman podman

# 4) 清理 .git，减小体积
find . -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true

echo -e "\n>> Packages.sh finished OK."
