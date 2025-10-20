#!/bin/bash
# ======================================================
#  Scripts/Packages_small.sh（SMALL 机型 / 极简外源包）
#  - 仅保留：homeproxy + nikki + luci-app-momo (+ gecoosac + netspeedtest)
#  - 提供 sing-box（从 immortalwrt/packages sparse 抽取）
#  - 主题：jerrykuku 的 argon + argon-config
# ======================================================

set -e
WRT_ROOT="${GITHUB_WORKSPACE}/wrt"
PKG_DIR="${WRT_ROOT}/package"

echo "=============================="
echo " SMALL Packages_small.sh started..."
echo "  - WRT_ROOT : ${WRT_ROOT}"
echo "  - PKG_DIR  : ${PKG_DIR}"
echo "=============================="

cd "${WRT_ROOT}"

add_singbox_sparse() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  echo ">> Adding sing-box (sparse from immortalwrt/packages)"
  git clone --depth=1 --filter=blob:none https://github.com/immortalwrt/packages "${tmpdir}"
  (
    cd "${tmpdir}"
    git sparse-checkout init --cone
    git sparse-checkout set net/sing-box
  )
  rm -rf "${PKG_DIR}/sing-box"
  mkdir -p "${PKG_DIR}"
  cp -a "${tmpdir}/net/sing-box" "${PKG_DIR}/"
  rm -rf "${tmpdir}"
}

# 1) sing-box 兜底
if [ ! -d "${PKG_DIR}/sing-box" ] && ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  add_singbox_sparse
fi

cd "${PKG_DIR}"

# 2) 主题（用 jerrykuku）
rm -rf "${PKG_DIR}/luci-theme-argon" "${PKG_DIR}/luci-app-argon-config"
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config

# 3) 轻量外源包（按你的要求）
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy          homeproxy
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki nikki
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-momo  OpenWrt-momo
git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac     openwrt-gecoosac
git clone --depth=1 -b js https://github.com/sirpdboy/luci-app-netspeedtest luci-app-netspeedtest

# 4) 清掉 .git
find "${PKG_DIR}" -type d -name ".git" -prune -exec rm -rf {} +

echo ">> SMALL package set prepared successfully!"
echo ">> Installed lightweight apps:"
printf '%s\n' homeproxy nikki OpenWrt-momo sing-box openwrt-gecoosac luci-app-netspeedtest
