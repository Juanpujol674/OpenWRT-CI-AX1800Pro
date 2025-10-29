#!/usr/bin/env bash
# Packages.sh — 统一 vendor：homeproxy + sing-box + momo + nikki + luci-app-tailscale
# 并容错第三方合集仓路径变动，避免重复定义冲突
set -euo pipefail

PKGDIR="package"
mkdir -p "$PKGDIR"

# ------- 工具：先清掉 feeds/package 里可能的同名包，防重复 -------
safe_purge_pkg() {
  local name="$1"
  find feeds -maxdepth 3 -type d -iname "*${name}*" -print0 2>/dev/null | xargs -0 -r rm -rf
  find package -maxdepth 2 -type d -iname "*${name}*" -print0 2>/dev/null | xargs -0 -r rm -rf
}

# ------- 固定来源：homeproxy（用你稳定可编译的 fork） -------
safe_purge_pkg "homeproxy"
git clone --depth=1 --single-branch https://github.com/VIKINGYFY/homeproxy "$PKGDIR/luci-app-homeproxy"

# ------- 固定来源：sing-box（sbwml 专用打包仓库） -------
safe_purge_pkg "sing-box"
git clone --depth=1 --single-branch https://github.com/sbwml/openwrt_sing-box "$PKGDIR/sing-box"

# ------- 固定来源：momo / nikki（上游易漂移，直接 vendor） -------
safe_purge_pkg "luci-app-momo"
safe_purge_pkg "luci-app-nikki"
git clone --depth=1 --single-branch https://github.com/nikkinikki-org/OpenWrt-momo  "$PKGDIR/luci-app-momo"
git clone --depth=1 --single-branch https://github.com/nikkinikki-org/OpenWrt-nikki "$PKGDIR/luci-app-nikki"

# ------- 固定来源：luci-app-tailscale（有些 feed 不带 UI，直接 vendor） -------
safe_purge_pkg "luci-app-tailscale"
git clone --depth=1 --single-branch https://github.com/asvow/luci-app-tailscale "$PKGDIR/luci-app-tailscale"

# ------- 其余第三方（保持你原逻辑，容错） -------
# kenzok8 合集（可能删包，做稀疏容错）
if git clone --depth=1 --filter=blob:none --sparse https://github.com/kenzok8/small-package _sp; then
  pushd _sp >/dev/null
  git sparse-checkout set daed-next luci-app-daed-next gost luci-app-gost luci-app-nginx luci-app-adguardhome || true
  for p in daed-next luci-app-daed-next gost luci-app-gost luci-app-nginx luci-app-adguardhome; do
    [ -e "$p" ] && mv -f "$p" "../$PKGDIR/" || echo "skip $p (not found upstream)"
  done
  popd >/dev/null; rm -rf _sp
fi

# kiddin9 合集（同上）
if git clone --depth=1 --filter=blob:none --sparse https://github.com/kiddin9/kwrt-packages _kwrt; then
  pushd _kwrt >/dev/null
  git sparse-checkout set natter2 luci-app-natter2 luci-app-cloudflarespeedtest luci-app-caddy openwrt-caddy || true
  for p in natter2 luci-app-natter2 luci-app-cloudflarespeedtest luci-app-caddy openwrt-caddy; do
    [ -e "$p" ] && mv -f "$p" "../$PKGDIR/" || echo "skip $p (not found upstream)"
  done
  popd >/dev/null; rm -rf _kwrt
fi

# Podman（保持你原来源）
safe_purge_pkg "podman"
git clone --depth=1 --single-branch https://github.com/breeze303/openwrt-podman "$PKGDIR/podman"

# Lucky（可选：若 feeds 没有则引入；两行留一行即可）
[ ! -d "$PKGDIR/luci-app-lucky" ] && git clone --depth=1 https://github.com/sirpdboy/luci-app-lucky "$PKGDIR/luci-app-lucky" || true

echo ">> Packages.sh done: homeproxy/sing-box/momo/nikki/luci-app-tailscale all vendored; duplicates purged."
