#!/usr/bin/env bash
set -e

# === Git稀疏克隆，只克隆指定目录到本地 ===
git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl"
  repodir=$(basename "$repourl")
  cd "$repodir"
  git sparse-checkout set "$@"
  mkdir -p ../package
  mv -f "$@" ../package
  cd .. && rm -rf "$repodir"
}

# === Lucky（App+二进制） ===
rm -rf package/lucky || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-lucky.git package/lucky

# === 删除官方冲突/重复的包（避免同名覆盖） ===
rm -rf feeds/luci/applications/luci-app-{dae*} || true
rm -rf feeds/packages/net/{dae*} || true

# === daed ===
rm -rf package/dae || true
git clone --depth=1 https://github.com/QiuSimons/luci-app-daed package/dae
mkdir -p Package/libcron && wget -qO Package/libcron/Makefile https://raw.githubusercontent.com/immortalwrt/packages/refs/heads/master/libs/libcron/Makefile

# === 小包集合 ===
git_sparse_clone main https://github.com/kenzok8/small-package daed-next luci-app-daed-next gost luci-app-gost luci-app-nginx luci-app-adguardhome
git_sparse_clone main https://github.com/kiddin9/kwrt-packages natter2 luci-app-natter2 luci-app-cloudflarespeedtest luci-app-caddy openwrt-caddy

# === Podman（App+后端） ===
rm -rf package/podman || true
git clone --depth 1 --single-branch https://github.com/breeze303/openwrt-podman package/podman

# === 提供 sing-box 包，满足 luci-app-homeproxy 依赖（若 feeds 缺失） ===
if [ ! -d "package/sing-box" ] && ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  echo ">> sing-box not found, cloning sbwml/sing-box ..."
  rm -rf package/*/sing-box feeds/*/sing-box || true
  git clone --depth=1 https://github.com/sbwml/sing-box package/sing-box && echo ">> Added sing-box successfully."
else
  echo ">> sing-box already exists, skip cloning."
fi

# === 安装所有 feeds ===
./scripts/feeds install -a

# === nginx 配置修复（保持你原本的改动） ===
wget -qO feeds/packages/net/nginx-util/files/nginx.config "https://gitee.com/white-wolf-vvvk/DK8sDDosFirewall/raw/main/openwrtnginx.conf"
cat feeds/packages/net/nginx-util/files/uci.conf.template || true
