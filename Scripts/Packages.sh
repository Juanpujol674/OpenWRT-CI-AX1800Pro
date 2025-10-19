#!/bin/bash
# =====================================================
# OpenWRT-CI Packages.sh — 大内存通用版（含 sing-box 自动修复）
# =====================================================

# 更新与安装指定软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	echo ""
	echo "==== Updating package: $PKG_NAME from $PKG_REPO ($PKG_BRANCH)"

	# 删除重复包（防止冲突）
	for NAME in "${PKG_LIST[@]}"; do
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Removed old directory: $DIR"
			done <<< "$FOUND_DIRS"
		fi
	done

	# 克隆仓库
	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git"

	# 判断提取方式
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find "./$REPO_NAME/" -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf "./$REPO_NAME/"
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f "$REPO_NAME" "$PKG_NAME"
	fi
}

# -----------------------------
# 主包列表
# -----------------------------
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
UPDATE_PACKAGE "luci-app-momo" "someone/openwrt-luci-app-momo" "main"

# -----------------------------
# 附加插件
# -----------------------------
git clone https://github.com/sirpdboy/luci-app-lucky.git package/lucky
git clone https://github.com/QiuSimons/luci-app-daed package/dae
mkdir -p Package/libcron && wget -O Package/libcron/Makefile https://raw.githubusercontent.com/immortalwrt/packages/refs/heads/master/libs/libcron/Makefile

# 拉取小杂包
function git_sparse_clone() {
	branch="$1" repourl="$2" && shift 2
	git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl"
	repodir=$(basename "$repourl")
	cd "$repodir" && git sparse-checkout set "$@"
	mv -f "$@" ../package
	cd .. && rm -rf "$repodir"
}

git_sparse_clone main https://github.com/kenzok8/small-package daed-next luci-app-daed-next gost luci-app-gost luci-app-nginx luci-app-adguardhome
git_sparse_clone main https://github.com/kiddin9/kwrt-packages natter2 luci-app-natter2 luci-app-cloudflarespeedtest luci-app-caddy openwrt-caddy
git clone --depth=1 --single-branch https://github.com/breeze303/openwrt-podman package/podman

# -----------------------------
# 修复 nginx 配置
# -----------------------------
wget "https://gitee.com/white-wolf-vvvk/DK8sDDosFirewall/raw/main/openwrtnginx.conf" -O ../feeds/packages/net/nginx-util/files/nginx.config
cat ../feeds/packages/net/nginx-util/files/uci.conf.template

# -----------------------------
# ✅ 强制修复 homeproxy 缺 sing-box 问题
# -----------------------------
echo ""
echo ">> Ensuring sing-box dependency for luci-app-homeproxy"
if [ ! -d "package/sing-box" ] && ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  echo ">> sing-box not found, cloning sbwml/sing-box ..."
  rm -rf package/*/sing-box feeds/*/sing-box || true
  git clone --depth=1 https://github.com/sbwml/sing-box package/sing-box
  echo ">> Added sing-box package for homeproxy dependency"
else
  echo ">> sing-box already present."
fi

# -----------------------------
# 再执行一次 feeds 注册
# -----------------------------
cd ..
./scripts/feeds update -a
./scripts/feeds install -a
echo ">> Feeds refreshed and sing-box registered successfully."
