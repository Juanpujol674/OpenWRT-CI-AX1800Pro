#!/bin/bash
# ======================================================
#  Scripts/Packages.sh  (Standard / 大内存)
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

# 0) 提供 sing-box（从 immortalwrt/packages 抽出 net/sing-box）
echo ">> Adding sing-box (sparse from immortalwrt/packages)"
TMP_DIR="$(mktemp -d)"
git clone --depth=1 https://github.com/immortalwrt/packages "${TMP_DIR}"
mkdir -p "${PKG_DIR}/sing-box"
rsync -a "${TMP_DIR}/net/sing-box/" "${PKG_DIR}/sing-box/"
rm -rf "${TMP_DIR}"

cd "${PKG_DIR}"

# 1) 主题 & 主题配置
git clone --depth=1 -b openwrt-24.10 https://github.com/sbwml/luci-theme-argon luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config luci-app-argon-config

# 2) 你要的科学/网络等应用
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy            homeproxy
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki   nikki
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-momo    OpenWrt-momo
# luci-app-momo 在该仓库的子目录
[ -d OpenWrt-momo/luci-app-momo ] && mv OpenWrt-momo/luci-app-momo ./luci-app-momo

# 其它（按你之前列表，保留原有）
git clone --depth=1 https://github.com/sirpdboy/luci-theme-kucat      luci-theme-kucat || true
git clone --depth=1 https://github.com/vernesong/OpenClash            OpenClash        || true
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall     openwrt-passwall || true
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall2    openwrt-passwall2|| true
git clone --depth=1 https://github.com/asvow/luci-app-tailscale       luci-app-tailscale || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-ddns-go      luci-app-ddns-go || true
git clone --depth=1 https://github.com/lisaac/luci-app-diskman        luci-app-diskman || true
git clone --depth=1 https://github.com/EasyTier/luci-app-easytier     luci-app-easytier|| true
git clone --depth=1 https://github.com/rockjake/luci-app-fancontrol   luci-app-fancontrol || true
git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac       openwrt-gecoosac || true
git clone --depth=1 -b v5 https://github.com/sbwml/luci-app-mosdns    luci-app-mosdns  || true
git clone --depth=1 -b js https://github.com/sirpdboy/luci-app-netspeedtest luci-app-netspeedtest || true
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2       luci-app-openlist2 || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-partexp      luci-app-partexp || true
git clone --depth=1 https://github.com/sbwml/luci-app-qbittorrent     luci-app-qbittorrent || true
git clone --depth=1 https://github.com/FUjr/QModem                    QModem || true
git clone --depth=1 https://github.com/VIKINGYFY/packages             packages || true
git clone --depth=1 https://github.com/lmq8267/luci-app-vnt           luci-app-vnt || true

# 3) 清理无关 .git 目录
find "${PKG_DIR}" -type d -name ".git" -prune -exec rm -rf {} +

echo ">> Standard package set prepared OK."
