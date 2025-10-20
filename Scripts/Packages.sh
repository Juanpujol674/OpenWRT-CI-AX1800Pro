#!/bin/bash
# ======================================================
#  Scripts/Packages.sh （大内存机型）
#  - 不再克隆“合集型 packages”仓库，以免夹带 dae/daed/v2raya
#  - 提供 sing-box（从 immortalwrt/packages sparse 抽取）
#  - 所有 GitHub clone 统一走 WRT-CORE.yml 里配置的 token 化 URL
#  - 必含 luci-app-momo（nikkinikki-org）
# ======================================================

set -e
WRT_ROOT="${GITHUB_WORKSPACE}/wrt"
PKG_DIR="${WRT_ROOT}/package"

echo "=============================="
echo " Standard Packages.sh started..."
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

# 1) sing-box 兜底（homeproxy 需要）
if [ ! -d "${PKG_DIR}/sing-box" ] && ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  add_singbox_sparse
fi

cd "${PKG_DIR}"

# 2) 主题（改用 jerrykuku 正源）
rm -rf "${PKG_DIR}/luci-theme-argon" "${PKG_DIR}/luci-app-argon-config"
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config

# 3) 你常用的外源包（保持精简 & 正源）
git clone --depth=1 https://github.com/sirpdboy/luci-theme-kucat
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy          homeproxy
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki nikki
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-momo  OpenWrt-momo

git clone --depth=1 https://github.com/vernesong/OpenClash          OpenClash
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall    openwrt-passwall
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall2   openwrt-passwall2

git clone --depth=1 https://github.com/asvow/luci-app-tailscale      luci-app-tailscale
git clone --depth=1 https://github.com/sirpdboy/luci-app-ddns-go     luci-app-ddns-go
git clone --depth=1 https://github.com/lisaac/luci-app-diskman       luci-app-diskman
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier    luci-app-easytier
git clone --depth=1 https://github.com/rockjake/luci-app-fancontrol  luci-app-fancontrol
git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac      openwrt-gecoosac
git clone --depth=1 -b v5 https://github.com/sbwml/luci-app-mosdns   luci-app-mosdns
git clone --depth=1 -b js https://github.com/sirpdboy/luci-app-netspeedtest luci-app-netspeedtest
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2      luci-app-openlist2
git clone --depth=1 https://github.com/sirpdboy/luci-app-partexp     luci-app-partexp
git clone --depth=1 https://github.com/sbwml/luci-app-qbittorrent    luci-app-qbittorrent
git clone --depth=1 https://github.com/FUjr/QModem                   QModem
git clone --depth=1 https://github.com/lmq8267/luci-app-vnt          luci-app-vnt

# 4) 清掉 .git，避免打进固件
find "${PKG_DIR}" -type d -name ".git" -prune -exec rm -rf {} +

echo ">> Standard package set prepared successfully!"
echo ">> Ensured packages:"
printf '%s\n' luci-theme-argon luci-app-argon-config homeproxy nikki OpenWrt-momo sing-box
