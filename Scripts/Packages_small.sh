#!/bin/bash
# ======================================================
#  Scripts/Packages_small.sh  (SMALL / 极简)
#  注意：在 wrt 根目录执行即可（脚本会自己 cd）
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

# 0) 提供 sing-box（从 immortalwrt/packages 抽出 net/sing-box）
echo ">> Adding sing-box (sparse from immortalwrt/packages)"
TMP_DIR="$(mktemp -d)"
git clone --depth=1 https://github.com/immortalwrt/packages "${TMP_DIR}"
mkdir -p "${PKG_DIR}/sing-box"
rsync -a "${TMP_DIR}/net/sing-box/" "${PKG_DIR}/sing-box/"
rm -rf "${TMP_DIR}"

cd "${PKG_DIR}"

# 1) 轻量集合：homeproxy + nikki + momo + gecoosac + netspeedtest
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy            homeproxy
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki   nikki
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-momo    OpenWrt-momo
[ -d OpenWrt-momo/luci-app-momo ] && mv OpenWrt-momo/luci-app-momo ./luci-app-momo

git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac       geccoosac  || git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac gecoosac
git clone --depth=1 -b js https://github.com/sirpdboy/luci-app-netspeedtest luci-app-netspeedtest || true

# 2) 仅保留轻主题 argon + 配置（改用 jerrykuku）
rm -rf "${WRT_ROOT}/feeds/luci/themes/luci-theme-"*
git clone --depth=1 -b openwrt-24.10 https://github.com/sbwml/luci-theme-argon luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config luci-app-argon-config

# 3) 清理重型包（容器/下载/代理等）
echo ">> Removing heavy packages (docker, lucky, qbittorrent, etc)"
rm -rf ${PKG_DIR}/*/{docker,containerd,dockerman,podman,lucky,openclash,passwall*,qbittorrent,gost,nginx,adguardhome}
rm -rf ${WRT_ROOT}/feeds/packages/net/{docker*,podman*,openclash*,qbittorrent*,v2ray*,xray*,gost*,adguardhome*,sing-box}
rm -rf ${WRT_ROOT}/feeds/luci/applications/luci-app-{dockerman,podman,openclash,passwall*,qbittorrent,gost,adguardhome,lucky}

# 4) 清理 .git
find "${PKG_DIR}" -type d -name ".git" -prune -exec rm -rf {} +
echo ">> SMALL package set prepared successfully."
