#!/bin/bash
# ============================================
# OpenWRT-CI Package Fetch & Update Script
# 作者: JuanPujol 项目维护版
# 功能: 管理第三方包拉取、更新、feed修复、依赖保障
# ============================================

set -e

# --------------------------------------------
# 函数: 安装或更新单个包
# --------------------------------------------
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	echo " "
	echo "==== Updating package: $PKG_NAME from $PKG_REPO ($PKG_BRANCH)"

	# 删除同名旧包（防冲突）
	for NAME in "${PKG_LIST[@]}"; do
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "→ Removed: $DIR"
			done <<< "$FOUND_DIRS"
		fi
	done

	# 克隆新仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理特殊结构
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# --------------------------------------------
# 第三方包清单
# --------------------------------------------
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "js"
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "xiaorouji/openwrt-passwall2" "main" "pkg"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "fancontrol" "rockjake/luci-app-fancontrol" "main"
UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/luci-app-netspeedtest" "js" "" "homebox speedtest"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"
UPDATE_PACKAGE "sing-box" "SagerNet/sing-box" "main"

# --------------------------------------------
# 必要组件克隆（如 Lucky、Daed、Natter2 等）
# --------------------------------------------
git clone https://github.com/sirpdboy/luci-app-lucky.git package/lucky

rm -rf ../feeds/luci/applications/luci-app-{dae*}
rm -rf ../feeds/packages/net/{dae*}

# QiuSimons daed
git clone https://github.com/QiuSimons/luci-app-daed package/dae
mkdir -p Package/libcron && wget -O Package/libcron/Makefile https://raw.githubusercontent.com/immortalwrt/packages/refs/heads/master/libs/libcron/Makefile

# 扩展组件仓库
function git_sparse_clone() {
	branch="$1" repourl="$2" && shift 2
	git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
	repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
	cd $repodir && git sparse-checkout set $@
	mv -f $@ ../package
	cd .. && rm -rf $repodir
}

git_sparse_clone main https://github.com/kenzok8/small-package daed-next luci-app-daed-next gost luci-app-gost luci-app-nginx luci-app-adguardhome
git_sparse_clone main https://github.com/kiddin9/kwrt-packages natter2 luci-app-natter2 luci-app-cloudflarespeedtest luci-app-caddy openwrt-caddy

# Podman 支持
git clone --depth 1 --single-branch https://github.com/breeze303/openwrt-podman package/podman

# 更新 feeds
echo ">> Updating and installing all feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# --------------------------------------------
# 确保 homeproxy 依赖的 sing-box 存在
# --------------------------------------------
if [ ! -d "package/sing-box" ] && ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  echo ">> Fetching sing-box package (for luci-app-homeproxy dependency)..."
  rm -rf package/*/sing-box feeds/*/sing-box || true
  git clone --depth=1 https://github.com/sbwml/sing-box package/sing-box
  echo ">> sing-box package added successfully."
fi

# --------------------------------------------
# 验证：是否成功拉取 sing-box
# --------------------------------------------
if [ -d "package/sing-box" ]; then
  echo "✅ sing-box detected at: package/sing-box"
else
  echo "⚠️  WARNING: sing-box not found after feeds install. Homeproxy may fail."
fi
