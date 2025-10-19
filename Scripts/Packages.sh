#!/bin/bash
# ======================================================
# Scripts/Packages.sh  —— 大内存/常规版
# 约定：本脚本在 wrt/package/ 目录内执行（WRT-CORE 已改为 cd ./wrt/package/ 再调用）
# 目标：
#  1) 保证 luci-app-homeproxy 依赖的 sing-box 一定存在（优先 sbwml 版本）
#  2) 提供你需要的外部包
# ======================================================

set -euo pipefail

# 小工具：打印标题
title() { echo -e "\n==== $*"; }

# 保险：当前目录校验（必须在 wrt/package/）
if [[ ! -f "../scripts/feeds" || ! -d "../feeds" ]]; then
  echo "ERROR: 请在 wrt/package/ 目录内执行本脚本！(当前: $(pwd))"
  exit 1
fi

# 通用函数：拉取指定仓库
#   参数: <dst_dir> <git_url> [<branch>]
clone_or_reset() {
  local dst="$1" url="$2" br="${3:-}"
  rm -rf "$dst"
  if [[ -n "$br" ]]; then
    git clone --depth=1 --single-branch --branch "$br" "$url" "$dst"
  else
    git clone --depth=1 "$url" "$dst"
  fi
}

# 0) 兜底：先把历史上残留/冲突的 sing-box 清掉（feeds & package）
title "Cleanup possibly conflicting sing-box"
rm -rf ./sing-box ../feeds/*/*/sing-box ../feeds/*/sing-box ../package/*/sing-box 2>/dev/null || true

# 1) 提供 sing-box（homeproxy 依赖）
#    判定规则：如果 feeds/ 或 package/ 中都没有 sing-box/Makefile，则克隆 sbwml/sing-box 到 ./sing-box
title "Ensure sing-box package exists"
if ! find .. -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . ; then
  echo ">> sing-box not found in feeds/package, cloning sbwml/sing-box ..."
  clone_or_reset "./sing-box" "https://github.com/sbwml/sing-box"
else
  echo ">> sing-box already present in feeds/package."
fi

# 2) 你现有的外部包（按原顺序），保留最少注释。
title "Updating external packages"

clone_or_reset "luci-theme-kucat"             "https://github.com/sirpdboy/luci-theme-kucat" "js"
clone_or_reset "homeproxy"                     "https://github.com/VIKINGYFY/homeproxy"       "main"
clone_or_reset "OpenWrt-nikki"                 "https://github.com/nikkinikki-org/OpenWrt-nikki" "main"
# OpenClash/Passwall/Passwall2 属于大体积包，保留原来逻辑：
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

# 3) 追加：Lucky/dae/podman 等你原来的拉取
title "Extra packages (lucky/dae/podman/…)"
rm -rf ./lucky && git clone --depth 1 --single-branch https://github.com/sirpdboy/luci-app-lucky.git lucky

rm -rf ./dae && git clone --depth 1 https://github.com/QiuSimons/luci-app-daed dae
mkdir -p Package/libcron && wget -q -O Package/libcron/Makefile https://raw.githubusercontent.com/immortalwrt/packages/refs/heads/master/libs/libcron/Makefile

# small-package / kwrt-packages 的稀疏拉取
git_sparse_clone() {
  local branch="$1" url="$2"; shift 2
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$url"
  local repo="$(basename "$url")"
  cd "$repo" && git sparse-checkout set "$@"
  mv -f "$@" ../
  cd .. && rm -rf "$repo"
}
git_sparse_clone main https://github.com/kenzok8/small-package daed-next luci-app-daed-next gost luci-app-gost luci-app-nginx luci-app-adguardhome
git_sparse_clone main https://github.com/kiddin9/kwrt-packages natter2 luci-app-natter2 luci-app-cloudflarespeedtest luci-app-caddy openwrt-caddy

rm -rf ./podman && git clone --depth 1 --single-branch https://github.com/breeze303/openwrt-podman podman

# 4) LuCI 主题：argon（如已在 feeds 存在不必清）
title "Ensure luci-theme-argon present"
# 留给 Settings/feeds 管理，这里不强删 feeds 里的主题。

# 5) 兜底：如果最后启用了 homeproxy，就强制把 sing-box 也选中（避免仅源码存在但未被选中）
#    这里只负责“源码层面”，真正把 CONFIG 置 y 在 Settings.sh 完成。
title "Post-check homeproxy/sing-box presence"
if grep -q '^CONFIG_PACKAGE_luci-app-homeproxy=y' ../.config 2>/dev/null; then
  # 有些场景 .config 还没生成，这里只做提示；最终 Settings.sh 里会二次兜底
  echo ">> NOTICE: luci-app-homeproxy is enabled in .config, sing-box source is ready."
else
  echo ">> homeproxy not explicitly enabled yet; sing-box source still provided for safety."
fi

# 6) 清理残留 .git，减小体积
find . -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true

echo -e "\n>> Packages.sh finished OK."
