#!/bin/bash
# ======================================================
#  Scripts/Packages_small.sh
#  轻量版：为 SMALL 机型（≤128MB 闪存）设计
#  注意：该脚本在 wrt/package/ 目录被调用
# ======================================================

set -euo pipefail

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

echo "=============================="
echo " SMALL Packages.sh started..."
echo "  - CWD : $(pwd)"
echo "=============================="

# -------------------------------
# 1️⃣ 提供 sing-box 包（homeproxy 依赖保护 / 可选使用）
# -------------------------------
if [ ! -d "package/sing-box" ] && ! find ../feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  echo ">> Adding lightweight sing-box (sbwml version)"
  rm -rf package/*/sing-box ../feeds/*/sing-box || true
  git clone --depth=1 https://github.com/sbwml/sing-box package/sing-box
fi

# -------------------------------
# 2️⃣ 轻量插件集合
#    - luci-app-momo：从 nikkinikki-org/OpenWrt-momo 抽取子目录 luci-app-momo
#    - 其它与你原脚本一致（homeproxy/nikki/gecoosac/netspeedtest）
# -------------------------------
# homeproxy（如 SMALL 配置中已设置 n，不会入固件，只是放在树里以防依赖检查）
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy package/homeproxy || true

# nikki
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki package/nikki

# luci-app-momo（从 OpenWrt-momo 仓库抽子目录）
echo ">> Fetching luci-app-momo from nikkinikki-org/OpenWrt-momo (subdir)"
rm -rf package/momo_tmp package/momo || true
git clone --depth=1 --filter=blob:none --sparse https://github.com/nikkinikki-org/OpenWrt-momo package/momo_tmp
(
  cd package/momo_tmp
  git sparse-checkout set luci-app-momo
)
mv package/momo_tmp/luci-app-momo package/momo
rm -rf package/momo_tmp

# gecoosac / netspeedtest（按你原脚本保留）
git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac package/gecoosac
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest package/netspeedtest

# -------------------------------
# 3️⃣ LuCI 基础保障（注意：需要回到 wrt 根目录再跑 feeds）
# -------------------------------
echo ">> Refreshing feeds (luci minimal set)"
pushd .. >/dev/null
  ./scripts/feeds update luci
  ./scripts/feeds install -a -p luci
  ./scripts/feeds install luci-base luci-compat luci-lib-base luci-lib-ipkg luci-lua-runtime
popd >/dev/null

# -------------------------------
# 4️⃣ 清理不适合 SMALL 的大型包
# -------------------------------
echo ">> Removing heavy packages (docker, lucky, qbittorrent, etc)"
rm -rf package/*/{docker,containerd,dockerman,podman,lucky,openclash,passwall*,qbittorrent,gost,nginx,adguardhome}
rm -rf ../feeds/packages/net/{docker*,podman*,openclash*,qbittorrent*,v2ray*,xray*,gost*,adguardhome*,sing-box}
rm -rf ../feeds/luci/applications/luci-app-{dockerman,podman,openclash,passwall*,qbittorrent,gost,adguardhome,lucky}

# -------------------------------
# 5️⃣ 仅保留轻主题 argon
# -------------------------------
echo ">> Keeping only argon theme"
rm -rf ../feeds/luci/themes/luci-theme-*
git clone --depth=1 -b openwrt-24.10 https://github.com/sbwml/luci-theme-argon package/luci-theme-argon
git clone --depth=1 https://github.com/sbwml/luci-app-argon-config package/luci-app-argon-config

# -------------------------------
# 6️⃣ 冗余 feed 清理
# -------------------------------
echo ">> Cleanup .git directories"
find ../feeds/ -type d -name ".git" -prune -exec rm -rf {} + || true
find package/ -type d -name ".git" -prune -exec rm -rf {} + || true

# -------------------------------
# ✅ 构建结果检查
# -------------------------------
echo ">> SMALL package set prepared successfully!"
echo ">> Installed lightweight apps:"
ls -1 package | grep -E "homeproxy|nikki|momo|gecoosac|netspeedtest|sing-box" || echo "⚠️ No small packages detected!"
