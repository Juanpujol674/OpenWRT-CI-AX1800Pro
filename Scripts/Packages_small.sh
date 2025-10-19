#!/bin/bash
# ======================================================
#  Scripts/Packages_small.sh
#  轻量版：为 SMALL 机型（≤128MB 闪存）设计
# ======================================================

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

echo "=============================="
echo " SMALL Packages.sh started..."
echo "=============================="

# -------------------------------
# 1️⃣ 提供 sing-box 包（homeproxy 依赖保护）
# -------------------------------
if [ ! -d "package/sing-box" ] && ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  echo ">> Adding lightweight sing-box (sbwml version)"
  rm -rf package/*/sing-box feeds/*/sing-box || true
  git clone --depth=1 https://github.com/sbwml/sing-box package/sing-box
fi

# -------------------------------
# 2️⃣ 轻量插件集合
# -------------------------------
git clone --depth=1 https://github.com/VIKINGYFY/homeproxy package/homeproxy
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki package/nikki
git clone --depth=1 https://github.com/sirpdboy/luci-app-momo package/momo
git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac package/gecoosac
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest package/netspeedtest

# -------------------------------
# 3️⃣ LuCI 基础保障
# -------------------------------
./scripts/feeds update luci
./scripts/feeds install -a -p luci
./scripts/feeds install luci-base luci-compat luci-lib-base luci-lib-ipkg luci-lua-runtime

# -------------------------------
# 4️⃣ 清理不适合 SMALL 的大型包
# -------------------------------
echo ">> Removing heavy packages (docker, lucky, qbittorrent, etc)"
rm -rf package/*/{docker,containerd,dockerman,podman,lucky,openclash,passwall*,qbittorrent,gost,nginx,adguardhome}
rm -rf feeds/packages/net/{docker*,podman*,openclash*,qbittorrent*,v2ray*,xray*,gost*,adguardhome*,sing-box}
rm -rf feeds/luci/applications/luci-app-{dockerman,podman,openclash,passwall*,qbittorrent,gost,adguardhome,lucky}

# -------------------------------
# 5️⃣ 仅保留轻主题 argon
# -------------------------------
rm -rf feeds/luci/themes/luci-theme-*
git clone --depth=1 -b openwrt-24.10 https://github.com/sbwml/luci-theme-argon package/luci-theme-argon
git clone --depth=1 https://github.com/sbwml/luci-app-argon-config package/luci-app-argon-config

# -------------------------------
# 6️⃣ 冗余 feed 清理
# -------------------------------
find feeds/ -type d -name ".git" -exec rm -rf {} +
find package/ -type d -name ".git" -exec rm -rf {} +

# -------------------------------
# ✅ 构建结果检查
# -------------------------------
echo ">> SMALL package set prepared successfully!"
echo ">> Installed lightweight apps:"
ls -1 package | grep -E "homeproxy|nikki|momo|gecoosac|netspeedtest|sing-box" || echo "⚠️ No small packages detected!"
